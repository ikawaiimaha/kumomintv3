alter table public.profiles enable row level security;
alter table public.collections enable row level security;
alter table public.items enable row level security;
alter table public.user_inventory enable row level security;
alter table public.user_wishlist enable row level security;
alter table public.tracked_collections enable row level security;
alter table public.listings enable row level security;
alter table public.offers enable row level security;
alter table public.offer_items enable row level security;
alter table public.notifications enable row level security;
alter table public.profile_likes enable row level security;

create or replace function public.is_staff() returns boolean language sql stable as $$
  select exists(select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','volunteer'));
$$;

create policy "profiles readable" on public.profiles for select using (true);
create policy "profiles self update" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

create policy "collections read" on public.collections for select using (true);
create policy "collections staff write" on public.collections for all using (public.is_staff()) with check (public.is_staff());
create policy "items read" on public.items for select using (true);
create policy "items staff write" on public.items for all using (public.is_staff()) with check (public.is_staff());

create policy "inventory own" on public.user_inventory for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "wishlist own" on public.user_wishlist for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "tracked own" on public.tracked_collections for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "listings read active" on public.listings for select using (status = 'active' or seller_id = auth.uid());
create policy "listings seller create" on public.listings for insert with check (seller_id = auth.uid());
create policy "listings seller update" on public.listings for update using (seller_id = auth.uid()) with check (seller_id = auth.uid());

create policy "offers read participants" on public.offers for select using (proposer_id = auth.uid() or receiver_id = auth.uid());
create policy "offers proposer create" on public.offers for insert with check (proposer_id = auth.uid());
create policy "offers participants update" on public.offers for update using (proposer_id = auth.uid() or receiver_id = auth.uid()) with check (proposer_id = auth.uid() or receiver_id = auth.uid());

create policy "offer_items read by offer participants" on public.offer_items for select using (exists(select 1 from public.offers o where o.id = offer_id and (o.proposer_id = auth.uid() or o.receiver_id = auth.uid())));
create policy "offer_items insert by proposer" on public.offer_items for insert with check (exists(select 1 from public.offers o where o.id = offer_id and o.proposer_id = auth.uid()));

create policy "notifications own" on public.notifications for select using (user_id = auth.uid());
create policy "notifications own update" on public.notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "likes read" on public.profile_likes for select using (true);
create policy "likes own create" on public.profile_likes for insert with check (liker_id = auth.uid());
create policy "likes own delete" on public.profile_likes for delete using (liker_id = auth.uid());
