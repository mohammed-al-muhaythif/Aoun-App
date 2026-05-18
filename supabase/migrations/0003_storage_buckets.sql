-- Attachments bucket for task files (PDF, images, xlsx, zip, etc.)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attachments',
  'attachments',
  false,
  20971520,  -- 20 MB
  array[
    'application/pdf',
    'image/png','image/jpeg','image/webp','image/gif',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-excel',
    'application/zip','application/x-zip-compressed',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain'
  ]
)
on conflict (id) do nothing;

-- Storage policies: only authed users can read or write to attachments bucket.
-- Path convention enforced by the client: <task_id>/<uuid>-<filename>
create policy "attachments: authed read"
  on storage.objects for select to authenticated
  using (bucket_id = 'attachments');

create policy "attachments: authed upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments' and owner = auth.uid());

create policy "attachments: owner delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'attachments' and owner = auth.uid());
