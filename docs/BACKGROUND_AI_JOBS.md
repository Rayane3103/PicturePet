### Background AI Jobs (Supabase + Flutter)

This app runs long AI jobs fully on Supabase so they continue if the app is closed. The flow:

- Flutter enqueues a job in `public.ai_jobs`
- Edge Function `ai-run` processes in the background (`EdgeRuntime.waitUntil`)
- Result is stored in Storage, `projects` and `project_edits` are updated
- Flutter listens to `ai_jobs` via Realtime and refreshes the UI

#### One-time setup

- Enable Realtime for `ai_jobs`:

```sql
alter publication supabase_realtime add table public.ai_jobs;
```

- Set Edge Function secrets:

```bash
# Replace the values accordingly
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
supabase secrets set FAL_API_KEY=YOUR_FAL_API_KEY
```

#### Local development

Enable background tasks when serving functions locally:

```toml
[edge_runtime]
policy = "per_worker"
```

Run locally:

```bash
supabase start
supabase functions serve
```

#### Test

- Open a project, run BG Remove or Remix; a job is queued and processed.
- On completion, the Editor applies the result automatically; Library refreshes.


