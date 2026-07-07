# AWAN — Club Task & Volunteer Management

Flutter mobile app for KSU's Awan student club. Backend: Supabase (Auth, Postgres, Realtime, Storage, Edge Functions). Push: OneSignal.

**Status:** Phase 1 + Phase 2 features (volunteer hours, teams, comments, notifications, push) + design refresh + demo-member seed.

---

## Prerequisites

| Tool | Install |
|---|---|
| Flutter 3.41+ | https://flutter.dev/docs/get-started/install |
| Supabase CLI | `winget install Supabase.CLI` or `scoop install supabase` |
| Deno (for Edge Function local dev, optional) | https://deno.land |

For the IDE to stop yelling about Deno types in `supabase/functions/*.ts`, install the **Deno** VS Code extension and add to user settings:
```json
"deno.enable": false,
"deno.enablePaths": ["supabase/functions"]
```
(The triple-slash type shims in `supabase/functions/_shared/deno.d.ts` keep things working even without the extension.)

---

## First-time setup

### 1. Flutter deps + env

```bash
cd aoun_app
flutter pub get
```

Copy `.env.example` to `.env` and fill in your Supabase URL + publishable key + OneSignal App ID. The REST API key is server-side only and gets stored as a Supabase secret (step 4 below).

### 2. Push schema + RLS + storage + notifications engine

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

Key migrations (see `supabase/migrations/` for the full ordered list):
- `0001_schema.sql` — tables, indexes, 8 committees
- `0002_rls_policies.sql` — full permission matrix
- `0003_storage_buckets.sql` — attachments bucket
- `0004_notifications_engine.sql` — auto-notification triggers, `push_sent` column, pg_cron overdue scanner
- `0005_roles_and_permanent_teams.sql` — extended admin roles, `is_permanent` teams, `lookup_login_email` RPC, `profiles.phone`/`university_id`
- `0006_real_member_seed.sql` — demo member roster + permanent teams (placeholder data — replace with your own)

### 3. Deploy Edge Functions

```bash
supabase secrets set ONESIGNAL_REST_KEY=os_v2_app_...
supabase secrets set ONESIGNAL_APP_ID=<your-onesignal-app-id>
supabase secrets set CRON_SECRET=$(openssl rand -hex 16)

supabase functions deploy send-push
supabase functions deploy dispatch-push --no-verify-jwt
```

### 4. Seed members + permanent teams

Seeding happens automatically when `supabase db push` applies `0006_real_member_seed.sql` — it creates a **placeholder demo roster** (board, leadership, head + vice for each of the 8 committees, sample members, app admin) plus the 4 permanent media sub-teams. Idempotent — safe to re-run.

To load your club's real roster, edit the `_seed_user(...)` calls in `0006_real_member_seed.sql` (and the matching IDs in `0013`/`0014`) before pushing, or run additional `select _seed_user(...)` calls from the SQL Editor at any time.

### 5. Schedule the push dispatcher (every minute)

In the Supabase Dashboard → **Cron**, create a job:
- Name: `dispatch-push`
- Schedule: `* * * * *`
- Type: HTTP Request
- Method: POST
- URL: `https://<your-project-ref>.supabase.co/functions/v1/dispatch-push`
- Headers: `x-cron-secret: <the CRON_SECRET you set>`

### 6. Run the app

```bash
flutter run
```

---

## Login

The login screen takes:
- **رقم الجوال** (phone) — formats accepted: `0512345678`, `512345678`, `+966512345678`
- **الرقم الجامعي** (university ID)

Internally these map to a synthetic email (`{universityId}@awan.club`) with the normalized phone as password. Users never see the email.

### Test accounts

Use any seeded demo member's phone + uni ID. Convenient ones for testing different roles:

| Role | Name | Phone | University ID |
|---|---|---|---|
| App admin (full power) | مشرف التطبيق (تجريبي) | 0500000021 | 400000021 |
| Board member | عضو مجلس الإدارة 1 (تجريبي) | 0500000001 | 400000001 |
| Club leader | قائد النادي (تجريبي) | 0500000003 | 400000003 |
| HR head | رئيس الموارد البشرية (تجريبي) | 0500000005 | 400000005 |
| HR member | عضو الموارد البشرية (تجريبي) | 0500000022 | 400000022 |
| Tech head | رئيس التقنية (تجريبي) | 0500000017 | 400000017 |
| Plain member | عضو الإرشاد (تجريبي) | 0500000026 | 400000026 |

---

## Architecture

```
lib/
├── main.dart                       Bootstrap + OneSignal auth-state binding
├── app.dart                        MaterialApp, RTL, ar locale, Cairo font
├── core/
│   ├── theme/                      purple #7F77DD + gradient + badges
│   ├── localization/               Arabic strings + intl formatters
│   ├── routing/                    go_router + bottom nav (5 tabs)
│   ├── permissions/                UI mirror of RLS (recognizes all admin roles)
│   ├── supabase/                   client init
│   └── push/                       OneSignal init + user bind (kIsWeb-guarded)
├── data/
│   ├── models/                     Committee, Task, Team, VolunteerHours, Notification, UserWithRoles
│   └── repositories/               Riverpod providers; realtime streams for comments + notifications
├── features/
│   ├── auth/                       phone + uni ID login
│   ├── dashboard/                  gradient welcome, stats, progress bars, task list
│   ├── tasks/                      list, detail (with comments), create
│   ├── teams/                      list, create
│   ├── hours/                      log, my-hours summary (week/month/year/all)
│   ├── members/                    directory, profile
│   └── notifications/              bell, list (realtime), composer
└── shared/widgets/                 NotificationBell, StatusBadge, PriorityBadge, EmptyState

supabase/
├── config.toml
├── migrations/                     0001..0028 (schema, RLS, seed, fixes)
└── functions/
    ├── _shared/deno.d.ts           IDE-only type shims for Deno + esm.sh
    ├── send-push/                  authed users send push to recipients (used by composer)
    └── dispatch-push/              cron-scheduled drain of unsent notifications → OneSignal
```

---

## Roles & permissions

| Role | Granted to | Power |
|---|---|---|
| `president` / `vice_president` | (legacy seed) | Full admin |
| `board_member` | مجلس الإدارة | Full admin |
| `club_leader` / `club_vice_leader` | قيادة الفريق | Full admin |
| `app_admin` | مشرف التطبيق (التقنية) | Full admin |
| `head` / `vice_head` | per-committee | Manage own committee + tasks |
| HR member | عضو في الموارد البشرية | See all members' hours + leaderboards (Phase 3) |
| Plain member | everyone else | Self only |

All six full-admin roles map to `Permissions.isPresident == true` and pass `is_club_president()` in RLS.

---

## Permanent teams

Pre-seeded sub-teams under اللجنة الإعلامية (`is_permanent = true`, **cannot be deleted by users**):

| Team |
|---|
| فريق الهوية البصرية |
| فريق التصوير والمونتاج |
| فريق كتابة المحتوى |
| فريق إدارة الحسابات |

Each team is seeded with a `leader` and a `vice_leader` from the demo roster (see `0006_real_member_seed.sql`).

`team_members.role` distinguishes `leader` / `vice_leader` / `member` within a team.

---

## Push notifications flow

```
trigger (insert/update on tasks/comments/hours/memberships)
  → enqueue_notification() inserts into public.notifications (push_sent=false)
  → Realtime subscription in app shows it instantly in bell
  → dispatch-push (every minute) drains unsent rows → OneSignal REST API
  → device receives tray push (mobile only; web push not supported by onesignal_flutter)
```

Manual sends from the composer (`/notifications/compose`) hit `send-push` directly — bypass the queue but still write a row to `notifications` so it shows up in the bell.

---

## Web vs mobile

The app runs on Chrome for development. **Push notifications won't fire on web** — `onesignal_flutter` doesn't support it. All in-app realtime (bell badge, notification list, task comments) works on web. Test push on an Android emulator or device.

---

## Security notes

- Publishable / anon key is bundled with the client — safe; RLS enforces access
- Service-role / secret key is never in the client or repo — only Edge Functions read it via `supabase secrets`
- The seed data in `0006_real_member_seed.sql` is placeholder demo data; passwords are derived from phone numbers, so **replace the demo roster and consider a stronger credential scheme before production**

---

## What's coming in Phase 3

- HR leaderboards (week/month/year/all-time)
- Committee-scoped hours view for committee heads
- President global hours view with edit/delete
- Offline polish, skeleton states, full validation messages
- Final permission matrix audit
