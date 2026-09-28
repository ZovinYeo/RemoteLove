create table if not exists public.planner_other_items (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references public.care_recipients(id) on delete cascade,
    title text not null,
    date timestamptz not null,
    notes text not null default '',
    repeat_rule text not null default 'Does not repeat',
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists planner_other_items_recipient_id_idx
on public.planner_other_items(recipient_id);

alter table public.planner_other_items enable row level security;

drop trigger if exists planner_other_items_touch_updated_at on public.planner_other_items;
create trigger planner_other_items_touch_updated_at before update on public.planner_other_items
for each row execute function public.touch_updated_at();

drop policy if exists "planner_other_items_recipient_access" on public.planner_other_items;
create policy "planner_other_items_recipient_access" on public.planner_other_items
for all
using (public.can_access_recipient(recipient_id))
with check (public.can_access_recipient(recipient_id));
