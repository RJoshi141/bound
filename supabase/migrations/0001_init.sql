-- Bound: initial schema
-- Clubs, members, books, shelves, notes, meetups, RSVPs, pick voting, recommendations.
-- Every club-scoped table is protected by row-level security: you only see clubs you're in.

-- ─── People ─────────────────────────────────────────────────────────────

create table public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  display_name text not null default '',
  silhouette   smallint not null default 0,        -- index into SilhouetteKind
  avatar_hex   text not null default '2F4A35',
  created_at   timestamptz not null default now()
);

-- every new sign-in gets a profile row
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', ''));
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─── Clubs ──────────────────────────────────────────────────────────────

create table public.clubs (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 80),
  invite_code text not null unique default upper(substr(md5(random()::text), 1, 6)),
  created_by  uuid not null default auth.uid() references public.profiles (id),
  created_at  timestamptz not null default now()
);

create type public.member_role as enum ('host', 'member');

create table public.club_members (
  club_id   uuid not null references public.clubs on delete cascade,
  user_id   uuid not null references public.profiles on delete cascade,
  role      public.member_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

-- helpers used by policies (security definer so they don't recurse through RLS)
create function public.is_member(club uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.club_members where club_id = club and user_id = auth.uid());
$$;

create function public.is_host(club uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.club_members where club_id = club and user_id = auth.uid() and role = 'host');
$$;

create function public.shares_club(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.club_members a
    join public.club_members b on a.club_id = b.club_id
    where a.user_id = auth.uid() and b.user_id = other
  );
$$;

-- ─── Books ──────────────────────────────────────────────────────────────

-- shared catalog, filled from Open Library search
create table public.books (
  id               uuid primary key default gen_random_uuid(),
  open_library_key text unique,
  isbn13           text unique,
  title            text not null,
  author           text not null default '',
  year             int,
  page_count       int not null default 0 check (page_count >= 0),
  created_at       timestamptz not null default now()
);

create type public.shelf_kind as enum ('to_read', 'reading', 'finished');

-- your copy: shelf, progress, favourite, spine colour
create table public.user_books (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references public.profiles on delete cascade,
  book_id      uuid not null references public.books on delete cascade,
  shelf        public.shelf_kind not null default 'to_read',
  current_page int not null default 0 check (current_page >= 0),
  is_favourite boolean not null default false,
  spine_hex    text not null default '8A2C22',
  added_at     timestamptz not null default now(),
  finished_at  timestamptz,
  unique (user_id, book_id)
);

-- ─── Notes ──────────────────────────────────────────────────────────────

create table public.notes (
  id                uuid primary key default gen_random_uuid(),
  club_id           uuid not null references public.clubs on delete cascade,
  book_id           uuid not null references public.books on delete cascade,
  author_id         uuid not null default auth.uid() references public.profiles on delete cascade,
  body              text not null check (char_length(body) between 1 and 500),
  rating            smallint check (rating between 1 and 5),
  page              int not null default 0,            -- where the author was; drives spoiler folding
  contains_spoilers boolean not null default false,
  discuss_at_meetup boolean not null default false,
  created_at        timestamptz not null default now()
);
create index notes_club_book on public.notes (club_id, book_id);

-- ─── Meetups ────────────────────────────────────────────────────────────

create table public.meetups (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs on delete cascade,
  number      int not null,
  book_id     uuid references public.books,
  starts_at   timestamptz not null,
  place       text not null default '',
  address     text not null default '',
  read_up_to  text not null default '',
  bringing    text not null default '',
  created_by  uuid not null default auth.uid() references public.profiles,
  created_at  timestamptz not null default now(),
  unique (club_id, number)
);

create type public.rsvp_status as enum ('going', 'maybe', 'not_going');

create table public.rsvps (
  meetup_id  uuid not null references public.meetups on delete cascade,
  user_id    uuid not null default auth.uid() references public.profiles on delete cascade,
  status     public.rsvp_status not null,
  updated_at timestamptz not null default now(),
  primary key (meetup_id, user_id)
);

-- ─── Next month's pick ──────────────────────────────────────────────────

create table public.pick_options (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs on delete cascade,
  book_id    uuid not null references public.books,
  closes_at  timestamptz,
  created_at timestamptz not null default now(),
  unique (club_id, book_id)
);

-- one vote per member per club; changing your vote = update the row
create table public.pick_votes (
  club_id    uuid not null references public.clubs on delete cascade,
  user_id    uuid not null default auth.uid() references public.profiles on delete cascade,
  option_id  uuid not null references public.pick_options on delete cascade,
  created_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

-- ─── Recommendations ────────────────────────────────────────────────────

create table public.recommendations (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs on delete cascade,
  from_user  uuid not null default auth.uid() references public.profiles on delete cascade,
  to_user    uuid not null references public.profiles on delete cascade,
  book_id    uuid not null references public.books,
  reason     text not null default '' check (char_length(reason) <= 200),
  is_added   boolean not null default false,
  created_at timestamptz not null default now()
);

-- ─── Club ledger (a view, so it never goes stale) ───────────────────────

create view public.club_ledger with (security_invoker = true) as
select
  m.club_id,
  m.id        as meetup_id,
  m.starts_at,
  b.id        as book_id,
  b.title,
  b.author,
  (select round(avg(n.rating)::numeric, 1)
     from public.notes n
    where n.club_id = m.club_id and n.book_id = m.book_id and n.rating is not null) as club_rating
from public.meetups m
join public.books b on b.id = m.book_id
where m.starts_at < now();

-- ─── RPCs: create / join a club ─────────────────────────────────────────

create function public.create_club(club_name text) returns public.clubs
language plpgsql security definer set search_path = '' as $$
declare new_club public.clubs;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into public.clubs (name, created_by) values (club_name, auth.uid()) returning * into new_club;
  insert into public.club_members (club_id, user_id, role) values (new_club.id, auth.uid(), 'host');
  return new_club;
end $$;

create function public.join_club(code text) returns public.clubs
language plpgsql security definer set search_path = '' as $$
declare found public.clubs;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into found from public.clubs where invite_code = upper(trim(code));
  if found.id is null then raise exception 'invalid invite code'; end if;
  insert into public.club_members (club_id, user_id) values (found.id, auth.uid())
  on conflict do nothing;
  return found;
end $$;

-- ─── Row-level security ─────────────────────────────────────────────────

alter table public.profiles        enable row level security;
alter table public.clubs           enable row level security;
alter table public.club_members    enable row level security;
alter table public.books           enable row level security;
alter table public.user_books      enable row level security;
alter table public.notes           enable row level security;
alter table public.meetups         enable row level security;
alter table public.rsvps           enable row level security;
alter table public.pick_options    enable row level security;
alter table public.pick_votes      enable row level security;
alter table public.recommendations enable row level security;

-- profiles: yourself + people you share a club with
create policy "read profiles in my clubs" on public.profiles for select to authenticated
  using (id = auth.uid() or public.shares_club(id));
create policy "update own profile" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- clubs: members read, hosts edit (create/join go through the RPCs)
create policy "members read club" on public.clubs for select to authenticated
  using (public.is_member(id));
create policy "hosts update club" on public.clubs for update to authenticated
  using (public.is_host(id));
create policy "hosts delete club" on public.clubs for delete to authenticated
  using (public.is_host(id));

-- members
create policy "members read members" on public.club_members for select to authenticated
  using (public.is_member(club_id));
create policy "leave or host removes" on public.club_members for delete to authenticated
  using (user_id = auth.uid() or public.is_host(club_id));
create policy "hosts change roles" on public.club_members for update to authenticated
  using (public.is_host(club_id));

-- books catalog: any signed-in reader can read and add
create policy "read catalog" on public.books for select to authenticated using (true);
create policy "add to catalog" on public.books for insert to authenticated with check (true);

-- your shelves: you write; clubmates can see progress ("Priya · p. 200")
create policy "read own or clubmates' shelves" on public.user_books for select to authenticated
  using (user_id = auth.uid() or public.shares_club(user_id));
create policy "write own shelves" on public.user_books for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- notes
create policy "members read notes" on public.notes for select to authenticated
  using (public.is_member(club_id));
create policy "members write notes" on public.notes for insert to authenticated
  with check (public.is_member(club_id) and author_id = auth.uid());
create policy "authors edit notes" on public.notes for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "authors delete notes" on public.notes for delete to authenticated
  using (author_id = auth.uid());

-- meetups: members read, hosts plan
create policy "members read meetups" on public.meetups for select to authenticated
  using (public.is_member(club_id));
create policy "hosts write meetups" on public.meetups for all to authenticated
  using (public.is_host(club_id)) with check (public.is_host(club_id));

-- rsvps
create policy "members read rsvps" on public.rsvps for select to authenticated
  using (public.is_member((select club_id from public.meetups where id = meetup_id)));
create policy "rsvp for yourself" on public.rsvps for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid()
              and public.is_member((select club_id from public.meetups where id = meetup_id)));

-- picks
create policy "members read options" on public.pick_options for select to authenticated
  using (public.is_member(club_id));
create policy "hosts manage options" on public.pick_options for all to authenticated
  using (public.is_host(club_id)) with check (public.is_host(club_id));

create policy "members read votes" on public.pick_votes for select to authenticated
  using (public.is_member(club_id));
create policy "vote for yourself" on public.pick_votes for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid()
              and public.is_member(club_id)
              and exists (select 1 from public.pick_options o where o.id = option_id and o.club_id = pick_votes.club_id));

-- recommendations: only the sender and recipient see them
create policy "read my recommendations" on public.recommendations for select to authenticated
  using (public.is_member(club_id) and (to_user = auth.uid() or from_user = auth.uid()));
create policy "recommend to clubmates" on public.recommendations for insert to authenticated
  with check (from_user = auth.uid() and public.is_member(club_id));
create policy "mark as added" on public.recommendations for update to authenticated
  using (to_user = auth.uid()) with check (to_user = auth.uid());

-- ─── Realtime ───────────────────────────────────────────────────────────

alter publication supabase_realtime add table public.notes, public.rsvps, public.pick_votes, public.meetups;
