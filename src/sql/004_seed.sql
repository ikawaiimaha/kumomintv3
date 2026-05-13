insert into public.collections (slug, name, description, collection_type) values
('sweet-cafe', 'Sweet Cafe', 'Pastel cafe decor collection', 'event'),
('cloud-bedroom', 'Cloud Bedroom', 'Soft bedroom set', 'gacha')
on conflict (slug) do nothing;

insert into public.items (slug, name, rarity, collection_id, main_category)
select 'sweet-cafe-chair','Sweet Cafe Chair','R', c.id, 'furniture' from public.collections c where c.slug='sweet-cafe'
on conflict (slug) do nothing;
