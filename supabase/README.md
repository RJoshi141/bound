# Bound · Supabase

Run these once, in order, in the Supabase dashboard (SQL Editor → paste → Run), or with the CLI: `supabase db push`.

| File | What it does |
| --- | --- |
| `0001_init.sql` | Tables, row-level security, the club ledger view, and the `create_club` / `join_club` functions |
| `0002_realtime_club.sql` | Live updates for vote options and new members |
| `0003_avatar_choice.sql` | Lets a profile's silhouette and colour be "not chosen yet" |

Keys: the app only ever gets the **anon public** key. Never put the `service_role` key in the app or the repo.
