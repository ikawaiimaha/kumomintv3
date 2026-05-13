create or replace function public.get_tracked_collection_progress(input_user_id uuid)
returns table (tracked_collection_count bigint, owned_items bigint, total_items bigint, percent numeric)
language sql stable as $$
with tracked as (select collection_id from public.tracked_collections where user_id = input_user_id),
totals as (select count(*) as total_items from public.items where collection_id in (select collection_id from tracked)),
owned as (select count(*) as owned_items from public.user_inventory ui join public.items i on i.id = ui.item_id where ui.user_id = input_user_id and ui.quantity > 0 and i.collection_id in (select collection_id from tracked))
select (select count(*) from tracked), (select owned_items from owned), (select total_items from totals),
case when (select total_items from totals)=0 then 0 else round(((select owned_items from owned)::numeric/(select total_items from totals)::numeric)*100,2) end;
$$;

create or replace function public.create_listing(input_item_id uuid, input_trade_method text, input_strict_rarity boolean, input_allow_bundles boolean, input_note text)
returns public.listings language plpgsql security definer as $$
declare uid uuid := auth.uid(); inv public.user_inventory; result public.listings;
begin
  select * into inv from public.user_inventory where user_id=uid and item_id=input_item_id;
  if inv is null or inv.quantity < 2 or inv.duplicate_guard then raise exception 'Listing validation failed'; end if;
  if exists(select 1 from public.listings where seller_id=uid and item_id=input_item_id and status='active') then raise exception 'Duplicate active listing'; end if;
  insert into public.listings(seller_id,item_id,trade_method,strict_rarity,allow_bundles,note) values(uid,input_item_id,input_trade_method,input_strict_rarity,input_allow_bundles,input_note) returning * into result;
  return result;
end; $$;
create or replace function public.create_offer(input_listing_id uuid, offered_items jsonb, input_trade_method text, input_message text)
returns public.offers language plpgsql security definer as $$
declare uid uuid := auth.uid(); l public.listings; o public.offers; elem jsonb; offered_item_id uuid; offered_qty integer;
begin
  select * into l from public.listings where id=input_listing_id and status='active';
  if l is null then raise exception 'Listing inactive'; end if;
  if l.allow_bundles = false and jsonb_array_length(offered_items) > 1 then raise exception 'Bundles not allowed'; end if;
  if l.strict_rarity and exists (
      select 1 from jsonb_array_elements(offered_items) e
      join public.items i on i.id=(e->>'item_id')::uuid
      join public.items req on req.id=l.item_id
      where i.rarity is distinct from req.rarity
  ) then raise exception 'Rarity mismatch'; end if;
  insert into public.offers(listing_id, proposer_id, receiver_id, requested_item_id, trade_method, message)
  values (l.id, uid, l.seller_id, l.item_id, input_trade_method, input_message) returning * into o;
  for elem in select * from jsonb_array_elements(offered_items)
  loop
    offered_item_id := (elem->>'item_id')::uuid; offered_qty := coalesce((elem->>'quantity')::integer,1);
    if not exists(select 1 from public.user_inventory where user_id=uid and item_id=offered_item_id and quantity >= offered_qty) then
      raise exception 'Insufficient offered quantity';
    end if;
    insert into public.offer_items(offer_id,item_id,quantity) values (o.id, offered_item_id, offered_qty);
  end loop;
  return o;
end; $$;

create or replace function public.accept_offer(input_offer_id uuid)
returns public.offers language plpgsql security definer as $$
declare o public.offers;
begin
  update public.offers set status='awaiting_confirmation', accepted_at=now() where id=input_offer_id and receiver_id=auth.uid() and status='pending' returning * into o;
  if o is null then raise exception 'Offer not updatable'; end if;
  return o;
end; $$;

create or replace function public.confirm_trade_complete(input_offer_id uuid)
returns public.offers language plpgsql security definer as $$
declare o public.offers;
begin
  update public.offers set proposer_confirmed = case when proposer_id=auth.uid() then true else proposer_confirmed end,
    receiver_confirmed = case when receiver_id=auth.uid() then true else receiver_confirmed end
  where id=input_offer_id and status in ('accepted','awaiting_confirmation') and (proposer_id=auth.uid() or receiver_id=auth.uid())
  returning * into o;
  if o.proposer_confirmed and o.receiver_confirmed then
    update public.offers set status='completed', completed_at=now() where id=o.id returning * into o;
    insert into public.trade_history(offer_id, proposer_id, receiver_id, final_status, snapshot)
    values (o.id, o.proposer_id, o.receiver_id, 'completed', to_jsonb(o));
  end if;
  return o;
end; $$;

create or replace function public.expire_old_offers()
returns integer language plpgsql security definer as $$
declare affected integer;
begin
  with expired as (
    update public.offers set status='expired' where status in ('pending','accepted','awaiting_confirmation') and expires_at < now() returning *
  )
  insert into public.trade_history(offer_id, proposer_id, receiver_id, final_status, snapshot)
  select id, proposer_id, receiver_id, 'expired', to_jsonb(expired) from expired;
  get diagnostics affected = row_count;
  return affected;
end; $$;
