-- Minimal seed data so you can actually log in and test the app end-to-end.
-- Run this in the Supabase SQL Editor AFTER 0001_init.sql.
-- Replace/extend with your real governorates, cities, titles, etc. later —
-- this is just enough to create one employee and submit one test request.

insert into public.governorates (name_en, name_ar) values
  ('Cairo', 'القاهرة'),
  ('Giza', 'الجيزة');

insert into public.cities (governorate_id, name_en, name_ar, latitude, longitude) values
  ((select id from public.governorates where name_en = 'Cairo'), 'Nasr City', 'مدينة نصر', 30.0511, 31.3656),
  ((select id from public.governorates where name_en = 'Cairo'), 'Heliopolis', 'مصر الجديدة', 30.0904, 31.3226),
  ((select id from public.governorates where name_en = 'Giza'), 'Dokki', 'الدقي', 30.0380, 31.2126),
  ((select id from public.governorates where name_en = 'Giza'), '6th of October', '٦ أكتوبر', 29.9660, 30.9232);

insert into public.titles (name, meal_cost) values
  ('Medical Representative', 150),
  ('Senior Medical Representative', 200),
  ('District Manager', 350);

-- reimbursement_policy already has one default row (27 km minimum, 1/km)
-- from 0001_init.sql — update it if your real policy differs, e.g.:
-- update public.reimbursement_policy set minimum_km = 27, price_per_km = 1.5;
