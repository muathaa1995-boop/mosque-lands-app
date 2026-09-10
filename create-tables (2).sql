-- ============================================
-- حذف أي جداول أو دوال سابقة (لو موجودة)
-- ============================================
drop table if exists nearby_facilities cascade;
drop table if exists land_images cascade;
drop table if exists lands cascade;
drop function if exists set_updated_at cascade;

-- تفعيل امتداد توليد UUID
create extension if not exists "pgcrypto";

-- ============================================
-- 1. جدول الأراضي (الجدول الرئيسي)
-- ============================================
create table lands (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  city text not null,
  district text,
  coordinates_lat double precision,
  coordinates_lng double precision,
  area_sqm numeric,
  status text not null default 'vacant'
    check (status in ('vacant', 'in_progress', 'funded')),
  estimated_cost numeric,
  description text,
  contact_info text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================
-- 2. جدول صور الأرض
-- ============================================
create table land_images (
  id uuid primary key default gen_random_uuid(),
  land_id uuid not null references lands(id) on delete cascade,
  image_url text not null,
  caption text,
  sort_order integer default 0
);

-- ============================================
-- 3. جدول المرافق المجاورة
-- ============================================
create table nearby_facilities (
  id uuid primary key default gen_random_uuid(),
  land_id uuid not null references lands(id) on delete cascade,
  facility_type text not null
    check (facility_type in ('housing', 'school', 'main_road', 'hospital', 'other_mosque', 'market', 'other')),
  name text,
  distance_meters numeric,
  notes text
);

-- ============================================
-- فهارس لتسريع الاستعلامات الشائعة
-- ============================================
create index idx_lands_city on lands(city);
create index idx_lands_status on lands(status);
create index idx_land_images_land_id on land_images(land_id);
create index idx_nearby_facilities_land_id on nearby_facilities(land_id);

-- ============================================
-- تحديث updated_at تلقائيًا عند أي تعديل
-- ============================================
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_lands_updated_at
before update on lands
for each row execute function set_updated_at();

-- ============================================
-- تفعيل Row Level Security (مطلوب في Supabase)
-- ============================================
alter table lands enable row level security;
alter table land_images enable row level security;
alter table nearby_facilities enable row level security;

-- القراءة متاحة للجميع (الواجهة العامة للمتبرعين)
create policy "public can read lands"
  on lands for select using (true);
create policy "public can read land_images"
  on land_images for select using (true);
create policy "public can read nearby_facilities"
  on nearby_facilities for select using (true);

-- التعديل (إضافة/تحديث/حذف) مسموح فقط للمستخدمين المسجّلين دخول (الإدارة)
create policy "authenticated can manage lands"
  on lands for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

create policy "authenticated can manage land_images"
  on land_images for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

create policy "authenticated can manage nearby_facilities"
  on nearby_facilities for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');
