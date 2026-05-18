# AWAN — Club Task & Volunteer Management

Flutter mobile app for KSU's Awan student club. Backend: Supabase (Auth, Postgres, Realtime, Storage, Edge Functions). Push: OneSignal.

**Status:** Phase 1 + Phase 2 features (volunteer hours, teams, comments, notifications, push) + design refresh + real-member seed.

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
cd C:\Users\moham\aoun_app
flutter pub get
```

`.env` contains your Supabase URL + publishable key + OneSignal App ID. The REST API key is server-side only and gets stored as a Supabase secret (step 4 below).

### 2. Push schema + RLS + storage + notifications engine

```bash
supabase link --project-ref iqhezsojsphjftwengvk
supabase db push
```

Migrations applied:
- `0001_schema.sql` — tables, indexes, 8 committees
- `0002_rls_policies.sql` — full permission matrix
- `0003_storage_buckets.sql` — attachments bucket
- `0004_notifications_engine.sql` — auto-notification triggers, `push_sent` column, pg_cron overdue scanner
- `0005_roles_and_permanent_teams.sql` — extended admin roles, `is_permanent` teams, `lookup_login_email` RPC, `profiles.phone`/`university_id`

### 3. Deploy Edge Functions

```bash
supabase secrets set ONESIGNAL_REST_KEY=os_v2_app_...
supabase secrets set ONESIGNAL_APP_ID=abb7b442-f4dc-4e76-a7fa-80a721ec2739
supabase secrets set CRON_SECRET=$(openssl rand -hex 16)

supabase functions deploy seed --no-verify-jwt
supabase functions deploy send-push
supabase functions deploy dispatch-push --no-verify-jwt
```

### 4. Seed real members + permanent teams

```bash
curl -X POST https://iqhezsojsphjftwengvk.supabase.co/functions/v1/seed
```

This creates **all real members** from the roster (board, leadership, committee heads + vices, ~150 members across 8 committees) plus the 4 permanent media sub-teams. Idempotent — safe to re-run.

### 5. Schedule the push dispatcher (every minute)

In the Supabase Dashboard → **Cron**, create a job:
- Name: `dispatch-push`
- Schedule: `* * * * *`
- Type: HTTP Request
- Method: POST
- URL: `https://iqhezsojsphjftwengvk.supabase.co/functions/v1/dispatch-push`
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

Use any seeded member's phone + uni ID. Convenient ones for testing different roles:

| Role | Name | Phone | University ID |
|---|---|---|---|
| App admin (full power) | محمد المحيذيف | 0530466740 | 446103998 |
| Board member | محمد الشتوي | 0554144761 | 442103121 |
| Club leader | سفانة الهديب | 0556577743 | 443201974 |
| HR head | عبدالعزيز الجنيدلي | 0500927474 | 446104004 |
| HR member | طرفة الطويل | 0557389186 | 444202222 |
| Tech head | فجر العتيبي | 0552456281 | 446008421 |
| Plain member | هيا القحطاني (إرشادية) | 0507317715 | 444927039 |

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
├── migrations/                     0001..0005
└── functions/
    ├── _shared/deno.d.ts           IDE-only type shims for Deno + esm.sh
    ├── seed/                       real members + permanent teams (data in members.ts)
    ├── send-push/                  authed users send push to recipients (used by composer)
    └── dispatch-push/              cron-scheduled drain of unsent notifications → OneSignal
```

---

## Roles & permissions

| Role | Granted to | Power |
|---|---|---|
| `president` / `vice_president` | (legacy seed) | Full admin |
| `board_member` | مجلس الإدارة (3 members) | Full admin |
| `club_leader` / `club_vice_leader` | قيادة الفريق (3 members) | Full admin |
| `app_admin` | محمد المحيذيف (التقنية) | Full admin |
| `head` / `vice_head` | per-committee | Manage own committee + tasks |
| HR member | عضو في الموارد البشرية | See all members' hours + leaderboards (Phase 3) |
| Plain member | everyone else | Self only |

All six full-admin roles map to `Permissions.isPresident == true` and pass `is_club_president()` in RLS.

---

## Permanent teams

Pre-seeded sub-teams under اللجنة الإعلامية (`is_permanent = true`, **cannot be deleted by users**):

| Team | Leader | Vice |
|---|---|---|
| فريق الهوية البصرية | لينا القحطاني | ديالا السلمي |
| فريق التصوير والمونتاج | ديما الدويش | عبدالله السبيعي |
| فريق كتابة المحتوى | سارة المقري | منار القحطاني |
| فريق إدارة الحسابات | سارة القرني | غالية الخرعان |

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
- The `seed` Edge Function uses `--no-verify-jwt` and admin APIs — **delete or disable it before production**

---

## What's coming in Phase 3

- HR leaderboards (week/month/year/all-time)
- Committee-scoped hours view for committee heads
- President global hours view with edit/delete
- Offline polish, skeleton states, full validation messages
- Final permission matrix audit
