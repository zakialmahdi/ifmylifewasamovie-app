-- ============================================================================
-- If My Life Was a Movie... — Supabase Postgres Schema & RLS Policies (Hardened)
-- Run this script in your Supabase Dashboard -> SQL Editor -> New Query.
-- Idempotent: safe to re-run at any time.
-- ============================================================================

-- 1. Non-exposed schema for internal trigger functions (never exposed via Data API)
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- 2. Profiles (1-to-1 with auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'maya',
  handle text not null unique check (handle = lower(handle)),
  invite_code text not null unique check (invite_code = upper(invite_code)),
  avatar_hatch text not null default 'cross'
    check (avatar_hatch in ('solid', 'diagonal', 'cross', 'lines', 'dots')),
  avatar_url text,
  paper text not null default 'lined'
    check (paper in ('plain', 'lined', 'grid')),
  music_source text not null default 'Spotify'
    check (music_source in ('Spotify', 'Apple', 'YouTube')),
  daily_reminder boolean not null default true,
  mood_prompts boolean not null default true,
  privacy_lock boolean not null default false,
  sharing_enabled boolean not null default true,
  sharing_audience text not null default 'all'
    check (sharing_audience in ('all', 'specific')),
  shared_friend_ids text[] not null default array[]::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure columns exist when upgrading an existing profiles table
alter table public.profiles
  add column if not exists avatar_url text;
alter table public.profiles
  add column if not exists sharing_enabled boolean not null default true;
alter table public.profiles
  add column if not exists sharing_audience text not null default 'all';
alter table public.profiles
  add column if not exists shared_friend_ids text[] not null default array[]::text[];
alter table public.profiles
  add column if not exists privacy_lock boolean not null default false;
alter table public.profiles
  add column if not exists daily_reminder boolean not null default true;
alter table public.profiles
  add column if not exists mood_prompts boolean not null default true;

-- 3. Daily Soundtrack Scenes
create table if not exists public.scenes (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  scene_date date not null,
  scene_no integer not null check (scene_no >= 1),
  song_title text not null,
  song_artist text not null,
  song_seconds integer not null check (song_seconds >= 0),
  song_art text not null default 'diagonal'
    check (song_art in ('solid', 'diagonal', 'cross', 'lines', 'dots')),
  song_video_id text,
  song_cover_url text,
  mood_name text not null,
  mood_hatch text not null default 'diagonal'
    check (mood_hatch in ('solid', 'diagonal', 'cross', 'lines', 'dots')),
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint scenes_user_date_unique unique (user_id, scene_date)
);

-- Ensure YouTube track metadata columns exist when upgrading an existing scenes table
alter table public.scenes
  add column if not exists song_video_id text;
alter table public.scenes
  add column if not exists song_cover_url text;

create index if not exists scenes_user_id_scene_date_idx
  on public.scenes (user_id, scene_date desc);

-- 4. Friendships & Co-Star Reel Invites
create table if not exists public.friendships (
  id bigint generated always as identity primary key,
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friendships_no_self check (requester_id <> addressee_id),
  constraint friendships_pair_unique unique (requester_id, addressee_id)
);

create index if not exists friendships_requester_id_idx
  on public.friendships (requester_id);

create index if not exists friendships_addressee_id_idx
  on public.friendships (addressee_id);

-- Partial indexes for high-frequency status queries & RLS subquery acceleration
create index if not exists friendships_pending_invites_idx
  on public.friendships (addressee_id, created_at desc)
  where status = 'pending';

create index if not exists friendships_accepted_requester_idx
  on public.friendships (requester_id, addressee_id)
  where status = 'accepted';

create index if not exists friendships_accepted_addressee_idx
  on public.friendships (addressee_id, requester_id)
  where status = 'accepted';

create unique index if not exists friendships_canonical_pair_idx
  on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

-- 5. Daily Scene Cheers
create table if not exists public.scene_cheers (
  scene_id bigint not null references public.scenes (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (scene_id, user_id)
);

create index if not exists scene_cheers_user_id_idx
  on public.scene_cheers (user_id);

-- ============================================================================
-- Triggers & Internal Functions (kept in non-exposed `private` schema)
-- ============================================================================

create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

revoke all on function private.set_updated_at() from public, anon, authenticated;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

drop trigger if exists set_scenes_updated_at on public.scenes;
create trigger set_scenes_updated_at
  before update on public.scenes
  for each row execute function private.set_updated_at();

drop trigger if exists set_friendships_updated_at on public.friendships;
create trigger set_friendships_updated_at
  before update on public.friendships
  for each row execute function private.set_updated_at();

-- Enforce participant immutability: prevent altering requester_id or addressee_id on existing friendships
create or replace function private.enforce_friendship_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.requester_id <> old.requester_id or new.addressee_id <> old.addressee_id then
    raise exception 'Cannot change requester_id or addressee_id on an existing friendship';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_friendship_immutability() from public, anon, authenticated;

drop trigger if exists check_friendship_immutability on public.friendships;
create trigger check_friendship_immutability
  before update on public.friendships
  for each row execute function private.enforce_friendship_immutability();

-- Automatically provision a profile row whenever a new auth.users row is created.
-- Hardened against duplicate key collisions on handle/invite_code to guarantee signup never aborts.
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  raw_name text;
  raw_avatar text;
  clean_slug text;
  short_code text;
  full_id text;
begin
  raw_name := coalesce(
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'name'), ''),
    pg_catalog.split_part(coalesce(new.email, 'director'), '@', 1),
    'director'
  );

  raw_avatar := coalesce(
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'avatar_url'), ''),
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'picture'), '')
  );

  clean_slug := pg_catalog.lower(
    pg_catalog.regexp_replace(raw_name, '[^a-zA-Z0-9]', '', 'g')
  );
  if clean_slug = '' then
    clean_slug := 'reel';
  end if;

  full_id := pg_catalog.replace(new.id::text, '-', '');
  short_code := pg_catalog.upper(pg_catalog.substr(full_id, 1, 4));

  begin
    insert into public.profiles (id, display_name, handle, invite_code, avatar_url)
    values (
      new.id,
      pg_catalog.left(raw_name, 32),
      '@' || pg_catalog.left(clean_slug, 12) || '_' || pg_catalog.lower(short_code),
      pg_catalog.upper(pg_catalog.left(clean_slug, 6)) || '-' || short_code,
      raw_avatar
    )
    on conflict (id) do nothing;
  exception when unique_violation then
    -- Collision fallback: append 8 unique characters from user id to guarantee uniqueness
    insert into public.profiles (id, display_name, handle, invite_code, avatar_url)
    values (
      new.id,
      pg_catalog.left(raw_name, 32),
      '@' || pg_catalog.left(clean_slug, 8) || '_' || pg_catalog.lower(pg_catalog.substr(full_id, 1, 8)),
      'REEL-' || pg_catalog.upper(pg_catalog.substr(full_id, 1, 8)),
      raw_avatar
    )
    on conflict (id) do nothing;
  end;

  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ============================================================================
-- Data API Grants & Row-Level Security (RLS)
-- ============================================================================

grant usage on schema public to authenticated;

-- Table-level grants: authenticated role
grant select, insert, update, delete on
  public.profiles,
  public.scenes,
  public.friendships,
  public.scene_cheers
to authenticated;

-- Principle of Least Privilege: restrict friendship updates to 'status' only
revoke update on public.friendships from authenticated;
grant update (status) on public.friendships to authenticated;

alter table public.profiles enable row level security;
alter table public.scenes enable row level security;
alter table public.friendships enable row level security;
alter table public.scene_cheers enable row level security;

-- ─────────────────────────────────────────────────────────────────────────────
-- Profiles policies
-- ─────────────────────────────────────────────────────────────────────────────

drop policy if exists "Authenticated users can look up profiles" on public.profiles;
drop policy if exists "Users can view their own profile" on public.profiles;
drop policy if exists "Users can look up discoverable profiles or friends" on public.profiles;

-- 1. Users can always read their own full profile (including privacy_lock, reminder settings)
create policy "Users can view their own profile"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

-- 2. Other users can discover profiles if privacy_lock is off, or if participating in a friendship (pending/accepted)
create policy "Users can look up discoverable profiles or friends"
  on public.profiles
  for select
  to authenticated
  using (
    privacy_lock = false
    or exists (
      select 1
      from public.friendships f
      where (
        (f.requester_id = (select auth.uid()) and f.addressee_id = profiles.id)
        or (f.addressee_id = (select auth.uid()) and f.requester_id = profiles.id)
      )
    )
  );

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "Users can delete their own profile" on public.profiles;
create policy "Users can delete their own profile"
  on public.profiles
  for delete
  to authenticated
  using ((select auth.uid()) = id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Scenes policies (Split for optimal query planning & index usage)
-- ─────────────────────────────────────────────────────────────────────────────

drop policy if exists "Users and connected friends can view shared scenes" on public.scenes;
drop policy if exists "Users can view their own scenes" on public.scenes;
drop policy if exists "Connected friends can view shared scenes" on public.scenes;

-- Fast index scan for own scenes
create policy "Users can view their own scenes"
  on public.scenes
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- Shared scenes visible to accepted friends when sharing is on & privacy_lock is off,
-- and either sharing_audience is 'all' or requester is in shared_friend_ids
create policy "Connected friends can view shared scenes"
  on public.scenes
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = scenes.user_id
        and coalesce(p.sharing_enabled, true) = true
        and coalesce(p.privacy_lock, false) = false
        and (
          coalesce(p.sharing_audience, 'all') = 'all'
          or (select auth.uid())::text = any(coalesce(p.shared_friend_ids, array[]::text[]))
        )
    )
    and exists (
      select 1
      from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester_id = (select auth.uid()) and f.addressee_id = scenes.user_id)
          or (f.addressee_id = (select auth.uid()) and f.requester_id = scenes.user_id)
        )
    )
  );

drop policy if exists "Users can insert their own scenes" on public.scenes;
create policy "Users can insert their own scenes"
  on public.scenes
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own scenes" on public.scenes;
create policy "Users can update their own scenes"
  on public.scenes
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own scenes" on public.scenes;
create policy "Users can delete their own scenes"
  on public.scenes
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Friendships policies
-- ─────────────────────────────────────────────────────────────────────────────

drop policy if exists "Users can view their own friendships" on public.friendships;
create policy "Users can view their own friendships"
  on public.friendships
  for select
  to authenticated
  using (
    (select auth.uid()) = requester_id
    or (select auth.uid()) = addressee_id
  );

drop policy if exists "Users can send friendship invites" on public.friendships;
create policy "Users can send friendship invites"
  on public.friendships
  for insert
  to authenticated
  with check (
    (select auth.uid()) = requester_id
    and requester_id <> addressee_id
    and status = 'pending'
  );

drop policy if exists "Addressee can accept friendship invite" on public.friendships;
create policy "Addressee can accept friendship invite"
  on public.friendships
  for update
  to authenticated
  using ((select auth.uid()) = addressee_id)
  with check (
    (select auth.uid()) = addressee_id
    and status = 'accepted'
  );

drop policy if exists "Participants can remove or dismiss friendships" on public.friendships;
create policy "Participants can remove or dismiss friendships"
  on public.friendships
  for delete
  to authenticated
  using (
    (select auth.uid()) = requester_id
    or (select auth.uid()) = addressee_id
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- Scene cheers policies
-- ─────────────────────────────────────────────────────────────────────────────

drop policy if exists "Users can view cheers on visible scenes" on public.scene_cheers;
create policy "Users can view cheers on visible scenes"
  on public.scene_cheers
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.scenes s
      where s.id = scene_cheers.scene_id
    )
  );

drop policy if exists "Users can cheer visible scenes" on public.scene_cheers;
create policy "Users can cheer visible scenes"
  on public.scene_cheers
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.scenes s
      where s.id = scene_cheers.scene_id
    )
  );

drop policy if exists "Users can remove their own cheers" on public.scene_cheers;
create policy "Users can remove their own cheers"
  on public.scene_cheers
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- ============================================================================
-- 6. Profile Avatars Storage Bucket & RLS Policies
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Avatar images are publicly readable" on storage.objects;
create policy "Avatar images are publicly readable"
  on storage.objects
  for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "Users can upload their own avatar" on storage.objects;
create policy "Users can upload their own avatar"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users can update their own avatar" on storage.objects;
create policy "Users can update their own avatar"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users can delete their own avatar" on storage.objects;
create policy "Users can delete their own avatar"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or name like (select auth.uid())::text || '/%'
    )
  );

-- ============================================================================
-- 7. Suggestions & Feature Feedback (Delivered to zakialmahdi@gmail.com)
-- ============================================================================

create table if not exists public.suggestions (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles (id) on delete set null,
  user_name text not null default '',
  user_handle text not null default '',
  user_email text,
  category text not null default 'New feature',
  message text not null,
  target_email text not null default 'zakialmahdi@gmail.com',
  created_at timestamptz not null default now()
);

alter table public.suggestions enable row level security;

drop policy if exists "Anyone can submit suggestions" on public.suggestions;
create policy "Anyone can submit suggestions"
  on public.suggestions
  for insert
  to authenticated, anon
  with check (true);

-- ============================================================================
-- 8. Self-Service Account Deletion RPC (`delete_my_account`) & Cleanup Trigger
-- ============================================================================

-- Ensure storage objects foreign key cascades on user deletion if present
do $$
begin
  if exists (
    select 1
    from information_schema.table_constraints
    where constraint_name = 'objects_owner_fkey'
      and table_schema = 'storage'
  ) then
    alter table storage.objects drop constraint objects_owner_fkey;
    alter table storage.objects
      add constraint objects_owner_fkey
      foreign key (owner) references auth.users (id) on delete cascade;
  end if;

  if exists (
    select 1
    from information_schema.table_constraints
    where constraint_name = 'objects_owner_id_fkey'
      and table_schema = 'storage'
  ) then
    alter table storage.objects drop constraint objects_owner_id_fkey;
    alter table storage.objects
      add constraint objects_owner_id_fkey
      foreign key (owner_id) references auth.users (id) on delete cascade;
  end if;
exception when others then
  null;
end;
$$;

-- Automatic trigger: cleans up storage objects and public tables whenever a user
-- is deleted directly from Supabase Auth Dashboard or via Admin API.
create or replace function public.handle_user_deletion()
returns trigger
language plpgsql
security definer
set search_path = 'public', 'auth', 'storage', 'pg_catalog'
as $$
begin
  -- 1. Remove storage objects owned by or uploaded into this user's folder
  begin
    delete from storage.objects
    where owner = old.id
       or bucket_id = 'avatars' and (
         name like old.id::text || '/%'
         or name like '%/' || old.id::text || '/%'
       );
  exception when undefined_column then
    begin
      delete from storage.objects
      where owner_id = old.id::text
         or bucket_id = 'avatars' and (
           name like old.id::text || '/%'
           or name like '%/' || old.id::text || '/%'
         );
    exception when others then
      null;
    end;
  when others then
    null;
  end;

  -- 2. Remove user suggestions / feedback
  begin
    delete from public.suggestions where user_id = old.id;
  exception when others then
    null;
  end;

  -- 3. Remove user cheer interactions
  begin
    delete from public.scene_cheers where user_id = old.id;
  exception when others then
    null;
  end;

  -- 4. Remove scenes recorded by this user
  begin
    delete from public.scenes where user_id = old.id;
  exception when others then
    null;
  end;

  -- 5. Remove friendships where this user was requester or addressee
  begin
    delete from public.friendships where requester_id = old.id or addressee_id = old.id;
  exception when others then
    null;
  end;

  -- 6. Remove profile row
  begin
    delete from public.profiles where id = old.id;
  exception when others then
    null;
  end;

  return old;
end;
$$;

revoke all on function public.handle_user_deletion() from public, anon, authenticated;

drop trigger if exists before_auth_user_deletion on auth.users;
create trigger before_auth_user_deletion
  before delete on auth.users
  for each row
  execute function public.handle_user_deletion();

-- User-callable RPC: allows an authenticated user to permanently delete their own account from auth.users
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = 'public', 'auth', 'storage', 'pg_catalog'
as $$
declare
  calling_uid uuid := (select auth.uid());
begin
  if calling_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- 1. Clean up storage files first to satisfy any foreign key constraints
  begin
    delete from storage.objects
    where owner = calling_uid
       or bucket_id = 'avatars' and (
         name like calling_uid::text || '/%'
         or name like '%/' || calling_uid::text || '/%'
       );
  exception when undefined_column then
    begin
      delete from storage.objects
      where owner_id = calling_uid::text
         or bucket_id = 'avatars' and (
           name like calling_uid::text || '/%'
           or name like '%/' || calling_uid::text || '/%'
         );
    exception when others then
      null;
    end;
  when others then
    null;
  end;

  -- 2. Explicitly remove public rows to prevent any trigger / constraint blocks
  begin
    delete from public.suggestions where user_id = calling_uid;
  exception when others then
    null;
  end;

  begin
    delete from public.scene_cheers where user_id = calling_uid;
  exception when others then
    null;
  end;

  begin
    delete from public.scenes where user_id = calling_uid;
  exception when others then
    null;
  end;

  begin
    delete from public.friendships where requester_id = calling_uid or addressee_id = calling_uid;
  exception when others then
    null;
  end;

  begin
    delete from public.profiles where id = calling_uid;
  exception when others then
    null;
  end;

  -- 3. Clean up active identities, sessions & MFA factors
  begin
    delete from auth.identities where user_id = calling_uid;
  exception when others then
    null;
  end;

  begin
    delete from auth.sessions where user_id = calling_uid;
  exception when others then
    null;
  end;

  begin
    delete from auth.mfa_factors where user_id = calling_uid;
  exception when others then
    null;
  end;

  begin
    delete from auth.one_time_tokens where user_id = calling_uid;
  exception when others then
    null;
  end;

  -- 4. Delete the auth.users record permanently
  delete from auth.users
  where id = calling_uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated, service_role;

-- ============================================================================
-- 9. Supabase Realtime Configuration
-- ============================================================================

-- Enable full row replication for friendships so realtime subscribers receive all fields
alter table public.friendships replica identity full;

-- Idempotently add friendships to supabase_realtime publication
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'friendships'
  ) then
    alter publication supabase_realtime add table public.friendships;
  end if;
end $$;

-- ============================================================================
-- 10. App Releases & Splash Screen Update Check
-- ============================================================================

create table if not exists public.app_releases (
  id bigint generated always as identity primary key,
  platform text not null default 'all'
    check (platform in ('all', 'android', 'ios', 'web')),
  latest_version text not null
    check (char_length(btrim(latest_version)) > 0),
  latest_build_number integer not null default 1
    check (latest_build_number >= 1),
  release_notes text not null default '',
  download_url text not null default 'https://github.com/zakialmahdi/ifmylifewasamovie-app/releases/latest',
  force_update boolean not null default false,
  is_active boolean not null default true,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.app_releases
  add column if not exists latest_build_number integer not null default 1;
alter table public.app_releases
  add column if not exists release_notes text not null default '';
alter table public.app_releases
  add column if not exists download_url text not null default 'https://github.com/zakialmahdi/ifmylifewasamovie-app/releases/latest';
alter table public.app_releases
  add column if not exists force_update boolean not null default false;
alter table public.app_releases
  add column if not exists is_active boolean not null default true;
alter table public.app_releases
  add column if not exists published_at timestamptz not null default now();

create index if not exists app_releases_active_platform_idx
  on public.app_releases (platform, latest_build_number desc, published_at desc)
  where is_active = true;

drop trigger if exists set_app_releases_updated_at on public.app_releases;
create trigger set_app_releases_updated_at
  before update on public.app_releases
  for each row execute function private.set_updated_at();

-- Grant anonymous + authenticated read-only access so splash checks work pre-login
grant usage on schema public to anon, authenticated;
grant select on public.app_releases to anon, authenticated;
grant all on public.app_releases to service_role;

alter table public.app_releases enable row level security;

drop policy if exists "Anyone can read active app releases" on public.app_releases;
create policy "Anyone can read active app releases"
  on public.app_releases
  for select
  to anon, authenticated
  using (is_active = true);

-- Seed current release row once so splash screen checks match latest release
insert into public.app_releases (
  platform,
  latest_version,
  latest_build_number,
  release_notes,
  download_url,
  force_update,
  is_active
)
select
  'all',
  '1.1.0',
  2,
  'Added calendar feeling/song album cover toggle, streamlined onboarding, and automatic update checks.',
  'https://github.com/zakialmahdi/ifmylifewasamovie-app/releases/latest',
  false,
  true
where not exists (
  select 1
  from public.app_releases
  where latest_version = '1.1.0'
    and latest_build_number = 2
);
