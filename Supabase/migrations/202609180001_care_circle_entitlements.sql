-- RemoteLove care-circle entitlements.
-- Non-destructive migration: adds shared plan access per care circle.

create table if not exists public.care_circle_entitlements (
    circle_id uuid primary key references public.care_circles(id) on delete cascade,
    plan_code text not null default 'free' check (plan_code in ('free', 'plusMonthly', 'plusYearly', 'proMonthly', 'proYearly', 'lifetime')),
    status text not null default 'active' check (status in ('active', 'trialing', 'inactive', 'expired', 'revoked')),
    billing_period text not null default 'none' check (billing_period in ('none', 'monthly', 'yearly', 'lifetime')),
    purchased_by uuid references auth.users(id) on delete set null,
    purchased_at timestamptz not null default now(),
    current_period_ends_at timestamptz,
    store_transaction_id text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists care_circle_entitlements_status_idx
on public.care_circle_entitlements(status);

create index if not exists care_circle_entitlements_purchased_by_idx
on public.care_circle_entitlements(purchased_by);

drop trigger if exists care_circle_entitlements_touch_updated_at on public.care_circle_entitlements;
create trigger care_circle_entitlements_touch_updated_at before update on public.care_circle_entitlements
for each row execute function public.touch_updated_at();

alter table public.care_circle_entitlements enable row level security;

grant select, insert, update, delete on public.care_circle_entitlements to authenticated;

drop policy if exists "care_circle_entitlements_member_read" on public.care_circle_entitlements;
create policy "care_circle_entitlements_member_read" on public.care_circle_entitlements
for select using (public.is_care_circle_member(circle_id));

drop policy if exists "care_circle_entitlements_family_write" on public.care_circle_entitlements;
create policy "care_circle_entitlements_family_write" on public.care_circle_entitlements
for all
using (
    exists (
        select 1
        from public.care_circle_members member
        where member.circle_id = care_circle_entitlements.circle_id
          and member.user_id = auth.uid()
          and member.active = true
          and lower(member.role) in ('owner', 'family')
    )
)
with check (
    exists (
        select 1
        from public.care_circle_members member
        where member.circle_id = care_circle_entitlements.circle_id
          and member.user_id = auth.uid()
          and member.active = true
          and lower(member.role) in ('owner', 'family')
    )
);
