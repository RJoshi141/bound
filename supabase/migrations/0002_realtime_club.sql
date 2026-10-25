-- Live updates for the Meetup and Club tabs: new vote options and new members.
alter publication supabase_realtime add table public.pick_options, public.club_members;
