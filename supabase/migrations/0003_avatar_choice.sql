-- Avatars: null means "not chosen yet", and the app picks one from your name.
-- (Before this, everyone defaulted to silhouette 0 / forest green.)
alter table public.profiles alter column silhouette drop not null, alter column silhouette set default null;
alter table public.profiles alter column avatar_hex drop not null, alter column avatar_hex set default null;
update public.profiles set silhouette = null where silhouette = 0;
update public.profiles set avatar_hex = null where avatar_hex = '2F4A35';
