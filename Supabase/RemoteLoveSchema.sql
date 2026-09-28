-- RemoteLove Supabase schema
-- Run this once in Supabase Dashboard > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.care_circles (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    caregiver_mode text not null default 'helper_only' check (caregiver_mode in ('helper_only', 'family_only', 'both')),
    health_enabled boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.care_circles
add column if not exists health_enabled boolean not null default true;

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

create table if not exists public.care_circle_invites (
    code text primary key,
    circle_id uuid not null references public.care_circles(id) on delete cascade,
    created_by uuid references auth.users(id) on delete set null,
    active boolean not null default true,
    created_at timestamptz not null default now()
);

alter table public.care_circle_invites
add column if not exists circle_id uuid references public.care_circles(id) on delete cascade;

alter table public.care_circle_invites
add column if not exists created_by uuid references auth.users(id) on delete set null;

alter table public.care_circle_invites
add column if not exists active boolean not null default true;

alter table public.care_circle_invites
add column if not exists created_at timestamptz not null default now();

alter table public.care_circle_invites
add column if not exists id uuid default gen_random_uuid();

alter table public.care_circle_invites
add column if not exists recipient_id uuid;

alter table public.care_circle_invites
add column if not exists invitation_type text not null default 'family';

alter table public.care_circle_invites
add column if not exists target_role text not null default 'family';

alter table public.care_circle_invites
add column if not exists permission_level text not null default 'Monitor and respond';

alter table public.care_circle_invites
add column if not exists expires_at timestamptz;

alter table public.care_circle_invites
add column if not exists max_uses integer;

alter table public.care_circle_invites
add column if not exists use_count integer not null default 0;

update public.care_circle_invites
set id = gen_random_uuid()
where id is null;

create table if not exists public.care_recipients (
    id uuid primary key default gen_random_uuid(),
    circle_id uuid not null references public.care_circles(id) on delete cascade,
    name text not null,
    label text not null,
    age integer not null check (age >= 0),
    relationship text not null,
    last_updated timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.care_circle_members (
    id uuid primary key default gen_random_uuid(),
    circle_id uuid not null references public.care_circles(id) on delete cascade,
    recipient_id uuid references public.care_recipients(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,
    name text not null,
    role text not null,
    permission text not null,
    active boolean not null default true,
    joined_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.care_circle_members
add column if not exists recipient_id uuid references public.care_recipients(id) on delete cascade;

alter table public.care_circle_members
add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.care_circle_members
alter column recipient_id drop not null;

alter table public.care_circle_members
add column if not exists permission_level text;

update public.care_circle_members
set permission_level = permission
where permission_level is null;

create table if not exists public.medicines (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references public.care_recipients(id) on delete cascade,
    name text not null,
    purpose text not null,
    instructions text not null,
    current_supply numeric not null default 0,
    dose numeric not null default 1,
    unit text not null,
    times_daily integer not null default 1,
    interval_days integer not null default 1,
    repeat_weekdays integer[],
    attention_days integer not null default 7,
    active boolean not null default true,
    first_time timestamptz not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.care_tasks (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references public.care_recipients(id) on delete cascade,
    title text not null,
    instructions text not null,
    scheduled_at timestamptz not null,
    frequency text not null,
    requires_photo boolean not null default false,
    state text not null check (state in ('pending', 'attending', 'done', 'paused')),
    notified_at timestamptz,
    medicine_id uuid references public.medicines(id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.appointments (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references public.care_recipients(id) on delete cascade,
    title text not null,
    date timestamptz not null,
    notes text not null,
    repeat_rule text not null,
    remind_three_days_before boolean not null default true,
    reminder_enabled boolean not null default true,
    reminder_days_before integer not null default 3 check (reminder_days_before between 1 and 30),
    reminder_count integer not null default 1 check (reminder_count between 1 and 8),
    state text not null check (state in ('scheduled', 'cancelled')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

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

create table if not exists public.health_logs (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references public.care_recipients(id) on delete cascade,
    category text not null,
    value numeric not null,
    notes text not null default '',
    recorded_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

create table if not exists public.care_updates (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references public.care_recipients(id) on delete cascade,
    author text not null,
    message text not null,
    mood text not null,
    created_at timestamptz not null default now()
);

create table if not exists public.activity_events (
    id uuid primary key default gen_random_uuid(),
    recipient_id uuid not null references public.care_recipients(id) on delete cascade,
    actor text not null,
    action text not null,
    detail text not null,
    created_at timestamptz not null default now()
);

create index if not exists care_circles_owner_id_idx on public.care_circles(owner_id);
create index if not exists care_circle_entitlements_status_idx on public.care_circle_entitlements(status);
create index if not exists care_circle_entitlements_purchased_by_idx on public.care_circle_entitlements(purchased_by);
create index if not exists care_circle_invites_circle_id_idx on public.care_circle_invites(circle_id);
create unique index if not exists care_circle_invites_id_unique_idx on public.care_circle_invites(id);
create index if not exists care_circle_invites_recipient_id_idx on public.care_circle_invites(recipient_id);
create index if not exists care_circle_invites_type_active_idx on public.care_circle_invites(invitation_type, active);
create index if not exists care_recipients_circle_id_idx on public.care_recipients(circle_id);
create index if not exists care_circle_members_circle_id_idx on public.care_circle_members(circle_id);
create index if not exists care_circle_members_user_id_idx on public.care_circle_members(user_id);
create index if not exists care_circle_members_recipient_id_idx on public.care_circle_members(recipient_id);
create unique index if not exists care_circle_members_circle_user_unique_idx
on public.care_circle_members(circle_id, user_id)
where user_id is not null;
create index if not exists care_tasks_recipient_id_idx on public.care_tasks(recipient_id);
create index if not exists medicines_recipient_id_idx on public.medicines(recipient_id);
create index if not exists appointments_recipient_id_idx on public.appointments(recipient_id);
create index if not exists planner_other_items_recipient_id_idx on public.planner_other_items(recipient_id);
create index if not exists health_logs_recipient_id_idx on public.health_logs(recipient_id);
create index if not exists care_updates_recipient_id_idx on public.care_updates(recipient_id);
create index if not exists activity_events_recipient_id_idx on public.activity_events(recipient_id);

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'care_circle_invites_recipient_id_fkey'
    ) then
        alter table public.care_circle_invites
        add constraint care_circle_invites_recipient_id_fkey
        foreign key (recipient_id) references public.care_recipients(id) on delete cascade;
    end if;
end;
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists care_circles_touch_updated_at on public.care_circles;
create trigger care_circles_touch_updated_at before update on public.care_circles
for each row execute function public.touch_updated_at();

drop trigger if exists care_circle_entitlements_touch_updated_at on public.care_circle_entitlements;
create trigger care_circle_entitlements_touch_updated_at before update on public.care_circle_entitlements
for each row execute function public.touch_updated_at();

drop trigger if exists care_recipients_touch_updated_at on public.care_recipients;
create trigger care_recipients_touch_updated_at before update on public.care_recipients
for each row execute function public.touch_updated_at();

drop trigger if exists care_circle_members_touch_updated_at on public.care_circle_members;
create trigger care_circle_members_touch_updated_at before update on public.care_circle_members
for each row execute function public.touch_updated_at();

drop trigger if exists care_tasks_touch_updated_at on public.care_tasks;
create trigger care_tasks_touch_updated_at before update on public.care_tasks
for each row execute function public.touch_updated_at();

drop trigger if exists medicines_touch_updated_at on public.medicines;
create trigger medicines_touch_updated_at before update on public.medicines
for each row execute function public.touch_updated_at();

drop trigger if exists appointments_touch_updated_at on public.appointments;
create trigger appointments_touch_updated_at before update on public.appointments
for each row execute function public.touch_updated_at();

drop trigger if exists planner_other_items_touch_updated_at on public.planner_other_items;
create trigger planner_other_items_touch_updated_at before update on public.planner_other_items
for each row execute function public.touch_updated_at();

create or replace function public.is_care_circle_member(target_circle_id uuid)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
    select exists (
        select 1
        from public.care_circles
        where id = target_circle_id
        and owner_id = auth.uid()
    )
    or exists (
        select 1
        from public.care_circle_members
        where circle_id = target_circle_id
        and user_id = auth.uid()
        and active = true
    );
$$;

create or replace function public.can_access_recipient(target_recipient_id uuid)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
    select exists (
        select 1
        from public.care_recipients
        where id = target_recipient_id
        and public.is_care_circle_member(circle_id)
    );
$$;

alter table public.profiles enable row level security;
alter table public.care_circles enable row level security;
alter table public.care_circle_entitlements enable row level security;
alter table public.care_circle_invites enable row level security;
alter table public.care_recipients enable row level security;
alter table public.care_circle_members enable row level security;
alter table public.care_tasks enable row level security;
alter table public.medicines enable row level security;
alter table public.appointments enable row level security;
alter table public.planner_other_items enable row level security;
alter table public.health_logs enable row level security;
alter table public.care_updates enable row level security;
alter table public.activity_events enable row level security;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
for select using (id = auth.uid());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
for insert with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "care_circles_member_access" on public.care_circles;
create policy "care_circles_member_access" on public.care_circles
for all using (public.is_care_circle_member(id)) with check (owner_id = auth.uid());

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

drop policy if exists "care_circle_invites_member_access" on public.care_circle_invites;
create policy "care_circle_invites_member_access" on public.care_circle_invites
for all using (public.is_care_circle_member(circle_id)) with check (public.is_care_circle_member(circle_id));

drop policy if exists "care_recipients_member_access" on public.care_recipients;
create policy "care_recipients_member_access" on public.care_recipients
for all using (public.is_care_circle_member(circle_id)) with check (public.is_care_circle_member(circle_id));

drop policy if exists "care_circle_members_member_access" on public.care_circle_members;
create policy "care_circle_members_member_access" on public.care_circle_members
for all using (public.is_care_circle_member(circle_id)) with check (public.is_care_circle_member(circle_id));

drop policy if exists "care_tasks_recipient_access" on public.care_tasks;
create policy "care_tasks_recipient_access" on public.care_tasks
for all using (public.can_access_recipient(recipient_id)) with check (public.can_access_recipient(recipient_id));

drop policy if exists "medicines_recipient_access" on public.medicines;
create policy "medicines_recipient_access" on public.medicines
for all using (public.can_access_recipient(recipient_id)) with check (public.can_access_recipient(recipient_id));

drop policy if exists "appointments_recipient_access" on public.appointments;
create policy "appointments_recipient_access" on public.appointments
for all using (public.can_access_recipient(recipient_id)) with check (public.can_access_recipient(recipient_id));

drop policy if exists "planner_other_items_recipient_access" on public.planner_other_items;
create policy "planner_other_items_recipient_access" on public.planner_other_items
for all using (public.can_access_recipient(recipient_id)) with check (public.can_access_recipient(recipient_id));

drop policy if exists "health_logs_recipient_access" on public.health_logs;
create policy "health_logs_recipient_access" on public.health_logs
for all using (public.can_access_recipient(recipient_id)) with check (public.can_access_recipient(recipient_id));

drop policy if exists "care_updates_recipient_access" on public.care_updates;
create policy "care_updates_recipient_access" on public.care_updates
for all using (public.can_access_recipient(recipient_id)) with check (public.can_access_recipient(recipient_id));

drop policy if exists "activity_events_recipient_access" on public.activity_events;
create policy "activity_events_recipient_access" on public.activity_events
for all using (public.can_access_recipient(recipient_id)) with check (public.can_access_recipient(recipient_id));

create or replace function public.create_care_circle_with_invite(circle_id_value uuid, invite_code_value text, display_name_value text)
returns table(circle_id uuid, invite_code text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    normalized_code text := upper(trim(invite_code_value));
begin
    if normalized_code = '' then
        raise exception 'Could not generate an invite code.';
    end if;

    if exists (
        select 1
        from public.care_circle_invites
        where upper(trim(code)) = normalized_code
    ) then
        raise exception 'That invite code already exists. Please generate another code.';
    end if;

    insert into public.profiles (id, display_name)
    values (auth.uid(), coalesce(nullif(trim(display_name_value), ''), 'Family member'))
    on conflict (id) do update
    set display_name = excluded.display_name;

    insert into public.care_circles (id, owner_id, name)
    values (circle_id_value, auth.uid(), coalesce(nullif(trim(display_name_value), ''), 'Family member') || '''s Care Circle')
    on conflict (id) do update
    set owner_id = excluded.owner_id,
        name = excluded.name;

    delete from public.care_circle_invites
    where circle_id = circle_id_value;

    insert into public.care_circle_invites (code, circle_id, created_by, active)
    values (normalized_code, circle_id_value, auth.uid(), true);

    delete from public.care_circle_members
    where circle_id = circle_id_value
    and user_id = auth.uid();

    insert into public.care_circle_members (id, circle_id, user_id, name, role, permission, active, joined_at)
    values (
        gen_random_uuid(),
        circle_id_value,
        auth.uid(),
        coalesce(nullif(trim(display_name_value), ''), 'Family member'),
        'Owner',
        'Full access',
        true,
        now()
    )
    on conflict do nothing;

    return query select circle_id_value, normalized_code;
end;
$$;

create or replace function public.join_care_circle_with_code(invite_code_value text, display_name_value text)
returns table(circle_id uuid, invite_code text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    normalized_code text := upper(trim(invite_code_value));
    joined_circle_id uuid;
    demo_circle_id uuid := '00000000-0000-0000-0000-000000000047';
begin
    if normalized_code = '' then
        raise exception 'Enter a family invite code.';
    end if;

    if normalized_code = 'LOVE2026' then
        insert into public.care_circles (id, owner_id, name, caregiver_mode)
        values (demo_circle_id, auth.uid(), 'RemoteLove Demo Care Circle', 'both')
        on conflict (id) do update
        set caregiver_mode = 'both';

        insert into public.care_circle_invites (code, circle_id, created_by, active)
        values ('LOVE2026', demo_circle_id, auth.uid(), true)
        on conflict (code) do update set active = true;
    end if;

    select invites.circle_id
    into joined_circle_id
    from public.care_circle_invites invites
    where upper(trim(invites.code)) = normalized_code
    and coalesce(invites.active, true) = true
    limit 1;

    if joined_circle_id is null then
        raise exception 'That invite code does not match an active care circle.';
    end if;

    insert into public.care_circle_members (id, circle_id, user_id, name, role, permission, active, joined_at)
    select
        gen_random_uuid(),
        joined_circle_id,
        auth.uid(),
        coalesce(nullif(trim(display_name_value), ''), 'Family member'),
        'Family',
        'Monitor and respond',
        true,
        now()
    where not exists (
        select 1
        from public.care_circle_members
        where circle_id = joined_circle_id
        and user_id = auth.uid()
    );

    return query select joined_circle_id, normalized_code;
end;
$$;

create or replace function public.normalize_invite_code(raw_code text)
returns text
language sql
immutable
as $$
    select upper(regexp_replace(coalesce(raw_code, ''), '[^a-zA-Z0-9]', '', 'g'));
$$;

create or replace function public.generate_care_invite_code()
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    candidate text;
begin
    loop
        candidate := upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 8));
        exit when not exists (
            select 1
            from public.care_circle_invites
            where public.normalize_invite_code(code) = candidate
        );
    end loop;

    return candidate;
end;
$$;

create or replace function public.create_initial_care_setup(
    recipient_name_value text,
    recipient_label_value text,
    recipient_age_value integer,
    relationship_value text,
    display_name_value text,
    caregiver_mode_value text default 'helper_only'
)
returns table(
    circle_id uuid,
    recipient_id uuid,
    family_invite_code text,
    helper_invite_code text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    current_user_id uuid := auth.uid();
    new_circle_id uuid := gen_random_uuid();
    new_recipient_id uuid := gen_random_uuid();
    family_code text := public.generate_care_invite_code();
    helper_code text := public.generate_care_invite_code();
    profile_name text := coalesce(nullif(trim(display_name_value), ''), 'Family member');
    recipient_name text := nullif(trim(recipient_name_value), '');
    recipient_label text := coalesce(nullif(trim(recipient_label_value), ''), 'Family');
    recipient_relationship text := coalesce(nullif(trim(relationship_value), ''), 'Family');
    selected_caregiver_mode text := lower(coalesce(nullif(trim(caregiver_mode_value), ''), 'helper_only'));
begin
    if current_user_id is null then
        raise exception 'Please sign in before creating a care setup.';
    end if;

    if recipient_name is null then
        raise exception 'Enter the care recipient name.';
    end if;

    if selected_caregiver_mode not in ('helper_only', 'family_only', 'both') then
        selected_caregiver_mode := 'helper_only';
    end if;

    while helper_code = family_code loop
        helper_code := public.generate_care_invite_code();
    end loop;

    insert into public.profiles (id, display_name)
    values (current_user_id, profile_name)
    on conflict (id) do update
    set display_name = excluded.display_name;

    insert into public.care_circles (id, owner_id, name, caregiver_mode)
    values (new_circle_id, current_user_id, recipient_label || '''s Care Circle', selected_caregiver_mode);

    insert into public.care_recipients (
        id,
        circle_id,
        name,
        label,
        age,
        relationship,
        last_updated
    )
    values (
        new_recipient_id,
        new_circle_id,
        recipient_name,
        recipient_label,
        greatest(coalesce(recipient_age_value, 0), 0),
        recipient_relationship,
        now()
    );

    insert into public.care_circle_members (
        id,
        circle_id,
        recipient_id,
        user_id,
        name,
        role,
        permission,
        permission_level,
        active,
        joined_at
    )
    values (
        gen_random_uuid(),
        new_circle_id,
        new_recipient_id,
        current_user_id,
        profile_name,
        'Owner',
        'Full access',
        'owner',
        true,
        now()
    );

    insert into public.care_circle_invites (
        code,
        circle_id,
        recipient_id,
        created_by,
        active,
        invitation_type,
        target_role,
        permission_level,
        max_uses,
        use_count
    )
    values
    (
        family_code,
        new_circle_id,
        new_recipient_id,
        current_user_id,
        true,
        'family',
        'Family',
        'Monitor and respond',
        null,
        0
    ),
    (
        helper_code,
        new_circle_id,
        new_recipient_id,
        current_user_id,
        true,
        'helper',
        'Helper',
        'Assigned care tasks',
        null,
        0
    );

    return query select new_circle_id, new_recipient_id, family_code, helper_code;
end;
$$;

create or replace function public.redeem_care_invitation(
    invite_code_value text,
    expected_type_value text,
    display_name_value text
)
returns table(circle_id uuid, invite_code text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    current_user_id uuid := auth.uid();
    normalized_code text := public.normalize_invite_code(invite_code_value);
    requested_type text := lower(coalesce(nullif(trim(expected_type_value), ''), 'family'));
    invite_record public.care_circle_invites%rowtype;
    profile_name text := coalesce(nullif(trim(display_name_value), ''), 'Care circle member');
    already_member boolean := false;
    assigned_role text;
    assigned_permission text;
begin
    if current_user_id is null then
        raise exception 'Please sign in before joining a care circle.';
    end if;

    if normalized_code = '' then
        raise exception 'Enter an invite code.';
    end if;

    if requested_type not in ('family', 'helper', 'viewer') then
        raise exception 'That invite code cannot be used for this access type.';
    end if;

    assigned_role := case
        when requested_type = 'helper' then 'Helper'
        when requested_type = 'viewer' then 'Viewer'
        else 'Family'
    end;

    assigned_permission := case
        when requested_type = 'helper' then 'Assigned care tasks'
        when requested_type = 'viewer' then 'Read only'
        else 'Monitor and respond'
    end;

    select invites.*
    into invite_record
    from public.care_circle_invites invites
    where public.normalize_invite_code(invites.code) = normalized_code
    and invites.active = true
    for update;

    if invite_record.code is null then
        raise exception 'That invite code does not match an active care profile.';
    end if;

    if lower(coalesce(invite_record.invitation_type, 'family')) <> requested_type then
        raise exception 'That invite code is for % access, not % access.',
            lower(coalesce(invite_record.invitation_type, 'family')),
            requested_type;
    end if;

    if invite_record.expires_at is not null and invite_record.expires_at <= now() then
        raise exception 'That invite code has expired.';
    end if;

    if invite_record.max_uses is not null and invite_record.use_count >= invite_record.max_uses then
        raise exception 'That invite code has already been fully used.';
    end if;

    insert into public.profiles (id, display_name)
    values (current_user_id, profile_name)
    on conflict (id) do update
    set display_name = excluded.display_name;

    select exists (
        select 1
        from public.care_circle_members members
        where members.circle_id = invite_record.circle_id
        and members.user_id = current_user_id
    )
    into already_member;

    if already_member then
        update public.care_circle_members members
        set active = true,
            name = profile_name,
            recipient_id = coalesce(members.recipient_id, invite_record.recipient_id),
            role = case when lower(members.role) = 'owner' then members.role else assigned_role end,
            permission = case when lower(members.role) = 'owner' then members.permission else assigned_permission end,
            permission_level = case when lower(members.role) = 'owner' then members.permission_level else assigned_permission end,
            updated_at = now()
        where members.circle_id = invite_record.circle_id
        and members.user_id = current_user_id;
    else
        insert into public.care_circle_members (
            id,
            circle_id,
            recipient_id,
            user_id,
            name,
            role,
            permission,
            permission_level,
            active,
            joined_at
        )
        values (
            gen_random_uuid(),
            invite_record.circle_id,
            invite_record.recipient_id,
            current_user_id,
            profile_name,
            assigned_role,
            assigned_permission,
            assigned_permission,
            true,
            now()
        );

        update public.care_circle_invites invites
        set use_count = use_count + 1
        where invites.code = invite_record.code;
    end if;

    return query select invite_record.circle_id, public.normalize_invite_code(invite_record.code);
end;
$$;

grant execute on function public.create_care_circle_with_invite(uuid, text, text) to authenticated;
grant execute on function public.join_care_circle_with_code(text, text) to authenticated;
grant execute on function public.create_initial_care_setup(text, text, integer, text, text, text) to authenticated;
grant execute on function public.redeem_care_invitation(text, text, text) to authenticated;

create or replace function public.seed_remote_love_demo_data(owner_id_value uuid)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    demo_circle_id uuid := '00000000-0000-0000-0000-000000000047';
    mum_id uuid := '10000000-0000-0000-0000-000000000001';
    dad_id uuid := '10000000-0000-0000-0000-000000000002';
    amlodipine_id uuid := '20000000-0000-0000-0000-000000000001';
    today timestamptz := date_trunc('day', now());
begin
    insert into public.care_circles (id, owner_id, name, caregiver_mode)
    values (demo_circle_id, owner_id_value, 'RemoteLove Demo Care Circle', 'both')
    on conflict (id) do update
    set caregiver_mode = 'both';

    insert into public.care_recipients (id, circle_id, name, label, age, relationship, last_updated)
    values
        (mum_id, demo_circle_id, 'Mei Ling', 'Mum', 68, 'Parent', now()),
        (dad_id, demo_circle_id, 'Wei Ming', 'Dad', 72, 'Parent', now() - interval '12 minutes')
    on conflict (id) do nothing;

    insert into public.care_circle_invites (
        code, circle_id, recipient_id, created_by, active, invitation_type, target_role, permission_level
    )
    values (
        'LOVE2026', demo_circle_id, mum_id, owner_id_value, true, 'family', 'Family', 'Monitor and respond'
    )
    on conflict (code) do update
    set circle_id = excluded.circle_id,
        recipient_id = excluded.recipient_id,
        active = true,
        invitation_type = 'family',
        target_role = 'Family',
        permission_level = 'Monitor and respond';

    insert into public.medicines (
        id, recipient_id, name, purpose, instructions, current_supply, dose, unit, times_daily, interval_days, attention_days, active, first_time
    )
    values
        (amlodipine_id, mum_id, 'Amlodipine', 'Blood pressure', 'Take after breakfast', 8, 1, 'tablets', 1, 1, 7, true, today + interval '9 hours'),
        ('20000000-0000-0000-0000-000000000002', mum_id, 'Vitamin D', 'Bone health', 'Take with food every two days', 6, 1, 'tablets', 1, 2, 5, true, today + interval '10 hours'),
        ('20000000-0000-0000-0000-000000000003', dad_id, 'Metformin', 'Blood sugar', 'Take after dinner', 18, 1, 'tablets', 1, 1, 7, true, today + interval '20 hours')
    on conflict (id) do nothing;

    insert into public.care_tasks (
        id, recipient_id, title, instructions, scheduled_at, frequency, requires_photo, state, notified_at, medicine_id
    )
    values
        ('30000000-0000-0000-0000-000000000001', mum_id, 'Breakfast', 'Oatmeal, fruit and warm water', today + interval '8 hours', 'Every day', false, 'done', null, null),
        ('30000000-0000-0000-0000-000000000002', mum_id, 'Morning medication', 'Amlodipine - take after breakfast', today + interval '9 hours', 'Every day', false, 'done', null, amlodipine_id),
        ('30000000-0000-0000-0000-000000000003', mum_id, 'Gentle walk', '15 minutes around the block', today + interval '10 hours 30 minutes', 'Every day', true, 'done', null, null),
        ('30000000-0000-0000-0000-000000000004', mum_id, 'Lunch', 'Serve a balanced meal', today + interval '12 hours 30 minutes', 'Every day', false, 'pending', now() - interval '10 minutes', null),
        ('30000000-0000-0000-0000-000000000005', mum_id, 'Afternoon water', 'One full glass', today + interval '15 hours', 'Every 3 hours - maximum 3 daily', false, 'pending', null, null),
        ('30000000-0000-0000-0000-000000000006', mum_id, 'Evening check-in', 'Record mood and comfort', today + interval '20 hours 30 minutes', 'Every day', false, 'pending', null, null),
        ('30000000-0000-0000-0000-000000000007', dad_id, 'Breakfast', 'Low-sugar breakfast', today + interval '8 hours', 'Every day', false, 'done', null, null),
        ('30000000-0000-0000-0000-000000000008', dad_id, 'Blood sugar check', 'Record reading before lunch', today + interval '11 hours 45 minutes', 'Every day', false, 'attending', now() - interval '5 minutes', null),
        ('30000000-0000-0000-0000-000000000009', dad_id, 'Evening walk', '20 minutes at a comfortable pace', today + interval '18 hours', 'Every day', false, 'pending', null, null)
    on conflict (id) do nothing;

    insert into public.appointments (
        id, recipient_id, title, date, notes, repeat_rule, remind_three_days_before, reminder_enabled, reminder_days_before, reminder_count, state
    )
    values
        ('40000000-0000-0000-0000-000000000001', mum_id, 'Blood pressure review', today + interval '2 days 10 hours', 'Bring recent readings and medicine list.', 'Does not repeat', true, true, 3, 1, 'scheduled'),
        ('40000000-0000-0000-0000-000000000002', mum_id, 'Annual health screening', today + interval '14 days 9 hours 30 minutes', 'Routine yearly check-up.', 'Every year', true, true, 7, 2, 'scheduled'),
        ('40000000-0000-0000-0000-000000000003', dad_id, 'Diabetes review', today + interval '5 days 14 hours', 'Bring glucose log.', 'Every 3 months', true, true, 3, 1, 'scheduled')
    on conflict (id) do nothing;

    insert into public.planner_other_items (
        id, recipient_id, title, date, notes, repeat_rule, active
    )
    values
        ('41000000-0000-0000-0000-000000000001', mum_id, 'Bring insurance card', today + interval '2 days 8 hours', 'Keep it ready before the clinic visit.', 'Does not repeat', true),
        ('41000000-0000-0000-0000-000000000002', dad_id, 'Charge glucose meter', today + interval '21 hours', 'Place it beside the medication box.', 'Every day', true)
    on conflict (id) do nothing;

    insert into public.health_logs (id, recipient_id, category, value, recorded_at, notes)
    values
        ('50000000-0000-0000-0000-000000000001', mum_id, 'weight', 63.2, today - interval '6 days' + interval '9 hours', 'Before breakfast'),
        ('50000000-0000-0000-0000-000000000002', mum_id, 'weight', 62.9, today - interval '4 days' + interval '9 hours', 'Before breakfast'),
        ('50000000-0000-0000-0000-000000000003', mum_id, 'weight', 62.7, today - interval '2 days' + interval '9 hours', 'Before breakfast'),
        ('50000000-0000-0000-0000-000000000004', mum_id, 'weight', 62.6, today + interval '9 hours', 'Before breakfast'),
        ('50000000-0000-0000-0000-000000000005', mum_id, 'bloodPressure', 134, today - interval '6 days' + interval '9 hours', 'Morning reading'),
        ('50000000-0000-0000-0000-000000000006', mum_id, 'bloodPressure', 131, today - interval '4 days' + interval '9 hours', 'After resting'),
        ('50000000-0000-0000-0000-000000000007', mum_id, 'bloodPressure', 129, today - interval '2 days' + interval '9 hours', 'Morning reading'),
        ('50000000-0000-0000-0000-000000000008', mum_id, 'bloodPressure', 128, today + interval '9 hours', 'Morning reading'),
        ('50000000-0000-0000-0000-000000000009', mum_id, 'mobility', 24, today - interval '2 days' + interval '9 hours', 'Walk and stretching'),
        ('50000000-0000-0000-0000-000000000010', mum_id, 'mobility', 25, today + interval '9 hours', 'Comfortable walk'),
        ('50000000-0000-0000-0000-000000000011', mum_id, 'hydration', 7, today + interval '9 hours', 'Regular water through the day'),
        ('50000000-0000-0000-0000-000000000012', mum_id, 'sleep', 7.5, today + interval '9 hours', 'Slept through the night'),
        ('50000000-0000-0000-0000-000000000013', dad_id, 'bloodSugar', 6.8, today - interval '2 days' + interval '9 hours', 'Before breakfast'),
        ('50000000-0000-0000-0000-000000000014', dad_id, 'bloodSugar', 6.5, today + interval '9 hours', 'Before breakfast')
    on conflict (id) do nothing;

    insert into public.care_updates (id, recipient_id, author, message, mood, created_at)
    values (
        '60000000-0000-0000-0000-000000000001',
        mum_id,
        'Ana',
        'Mum ate well and was cheerful this morning. We walked downstairs before it became warm.',
        'Cheerful',
        now() - interval '30 minutes'
    )
    on conflict (id) do nothing;

    insert into public.activity_events (id, recipient_id, actor, action, detail, created_at)
    values
        ('70000000-0000-0000-0000-000000000001', mum_id, 'Ana - Helper', 'Completed Morning medication', 'Marked the 9:00 AM care task as done.', now() - interval '42 minutes'),
        ('70000000-0000-0000-0000-000000000002', mum_id, 'Ana - Helper', 'Sent a care update', 'Shared a cheerful mood update with the family.', now() - interval '65 minutes'),
        ('70000000-0000-0000-0000-000000000003', mum_id, 'Zovin - Owner', 'Updated Blood pressure review', 'Kept the three-day appointment reminder.', now() - interval '3 hours'),
        ('70000000-0000-0000-0000-000000000004', dad_id, 'Ana - Helper', 'Attending to Blood sugar check', 'Family can see that the requested task is in progress.', now() - interval '5 minutes')
    on conflict (id) do nothing;

    return demo_circle_id;
end;
$$;

create or replace function public.join_remote_love_demo(
    display_name_value text,
    role_value text
)
returns table(circle_id uuid, invite_code text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    current_user_id uuid := auth.uid();
    demo_circle_id uuid := '00000000-0000-0000-0000-000000000047';
    normalized_role text := lower(coalesce(nullif(trim(role_value), ''), 'family'));
    member_role text;
    member_permission text;
    profile_name text := coalesce(nullif(trim(display_name_value), ''), 'Demo user');
begin
    if current_user_id is null then
        raise exception 'Please sign in before loading the demo.';
    end if;

    perform public.seed_remote_love_demo_data(current_user_id);

    member_role := case when normalized_role = 'helper' then 'Helper' else 'Family' end;
    member_permission := case when normalized_role = 'helper' then 'Tasks and updates' else 'Monitor and respond' end;

    insert into public.profiles (id, display_name)
    values (current_user_id, profile_name)
    on conflict (id) do update set display_name = excluded.display_name;

    update public.care_circle_members
    set name = profile_name,
        role = member_role,
        permission = member_permission,
        permission_level = member_permission,
        recipient_id = null,
        active = true
    where circle_id = demo_circle_id
      and user_id = current_user_id;

    if not found then
        insert into public.care_circle_members (
            id, circle_id, recipient_id, user_id, name, role, permission, permission_level, active, joined_at
        )
        values (
            gen_random_uuid(), demo_circle_id, null, current_user_id, profile_name, member_role, member_permission, member_permission, true, now()
        );
    end if;

    return query select demo_circle_id, 'LOVE2026'::text;
end;
$$;

grant execute on function public.seed_remote_love_demo_data(uuid) to authenticated;
grant execute on function public.join_remote_love_demo(text, text) to authenticated;

alter table if exists public.medicines
    add column if not exists dose_times timestamptz[];

alter table if exists public.medicines
    add column if not exists repeat_weekdays integer[];

notify pgrst, 'reload schema';
