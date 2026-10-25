# Bound · Supabase

`migrations/0001_init.sql` creates the whole backend: tables, row-level security, the club ledger view,
and the `create_club` / `join_club` functions.

Run it once in the Supabase dashboard (SQL Editor → paste → Run), or with the CLI: `supabase db push`.

Keys: the app only ever gets the **anon public** key. Never put the `service_role` key in the app or the repo.
