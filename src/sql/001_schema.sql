create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text,
  avatar_color text,
  hkdv_friend_code text,
  role text not null default 'user' check (role in ('user', 'volunteer', 'admin')),
  reputation integer not null default 0,
  dream_mints integer not null default 0,
  login_streak integer not null default 0,
  last_claim_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(), slug text unique not null, name text not null,
  description text, cover_image_url text, collection_type text, source_url text,
  created_by uuid references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.items (
  id uuid primary key default gen_random_uuid(), slug text unique not null, name text not null, image_url text,
  rarity text check (rarity in ('SSR','SR','R','N')), collection_id uuid references public.collections(id) on delete set null,
  collection_type text, main_category text, sub_category text, character_tag text,
  is_signature boolean not null default false, is_animated boolean not null default false, is_chameleon boolean not null default false,
  demand_score numeric not null default 1, source_url text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.user_inventory (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete cascade, quantity integer not null default 0 check (quantity >= 0),
  duplicate_guard boolean not null default false, acquired_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (user_id, item_id)
);
create table if not exists public.user_wishlist (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete cascade, heart_tier integer not null check (heart_tier between 1 and 3),
  note text, created_at timestamptz not null default now(), unique (user_id, item_id)
);
create table if not exists public.tracked_collections (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  collection_id uuid not null references public.collections(id) on delete cascade, created_at timestamptz not null default now(), unique (user_id, collection_id)
);
create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(), seller_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete cascade, status text not null default 'active' check (status in ('active','paused','closed','expired')),
  trade_method text not null default 'exchange' check (trade_method in ('exchange','gift','either')),
  strict_rarity boolean not null default true, allow_bundles boolean not null default false, note text,
  created_at timestamptz not null default now(), expires_at timestamptz, closed_at timestamptz
);
create table if not exists public.offers (
  id uuid primary key default gen_random_uuid(), listing_id uuid not null references public.listings(id) on delete cascade,
  proposer_id uuid not null references public.profiles(id) on delete cascade, receiver_id uuid not null references public.profiles(id) on delete cascade,
  requested_item_id uuid references public.items(id), status text not null default 'pending' check (status in ('pending','accepted','awaiting_confirmation','completed','declined','expired','cancelled')),
  trade_method text check (trade_method in ('exchange','gift')), proposer_confirmed boolean not null default false, receiver_confirmed boolean not null default false,
  message text, created_at timestamptz not null default now(), accepted_at timestamptz, completed_at timestamptz,
  expires_at timestamptz not null default (now() + interval '24 hours')
);
create table if not exists public.offer_items (
  id uuid primary key default gen_random_uuid(), offer_id uuid not null references public.offers(id) on delete cascade,
  item_id uuid not null references public.items(id), quantity integer not null default 1 check (quantity > 0)
);
create table if not exists public.trade_history (
  id uuid primary key default gen_random_uuid(), offer_id uuid references public.offers(id), proposer_id uuid references public.profiles(id),
  receiver_id uuid references public.profiles(id), final_status text check (final_status in ('completed','declined','expired','cancelled')),
  snapshot jsonb not null, created_at timestamptz not null default now()
);
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null, title text not null, body text, read_at timestamptz, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table if not exists public.profile_likes (
  id uuid primary key default gen_random_uuid(), liker_id uuid not null references public.profiles(id) on delete cascade,
  target_user_id uuid not null references public.profiles(id) on delete cascade, created_at timestamptz not null default now(),
  unique (liker_id, target_user_id), check (liker_id <> target_user_id)
);
