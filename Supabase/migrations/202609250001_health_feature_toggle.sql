alter table public.care_circles
add column if not exists health_enabled boolean not null default true;

update public.care_circles
set health_enabled = true
where health_enabled is null;
