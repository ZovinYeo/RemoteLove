-- RemoteLove typed onboarding and invitation redemption.
-- Review against the deployed schema before applying to production.

create extension if not exists pgcrypto;

create table if not exists public.care_invitations (
    id uuid primary key default gen_random_uuid(),
    code text not null unique,
    invitation_type text not null check (invitation_type in ('family', 'helper')),
    target_role text not null check (target_role in ('owner', 'family', 'helper', 'viewer')),
    permission_level text not null,
    circle_id uuid not null references public.care_circles(id) on delete cascade,
    created_by uuid not null references auth.users(id),
    active boolean not null default true,
    revoked_at timestamptz,
    expires_at timestamptz,
    redeemed_at timestamptz,
    redeemed_by uuid references auth.users(id),
    created_at timestamptz not null default now()
);

create table if not exists public.care_invitation_recipients (
    invitation_id uuid not null references public.care_invitations(id) on delete cascade,
    recipient_id uuid not null references public.care_recipients(id) on delete cascade,
    primary key (invitation_id, recipient_id)
);

create table if not exists public.member_recipient_access (
    member_id uuid not null references public.care_circle_members(id) on delete cascade,
    recipient_id uuid not null references public.care_recipients(id) on delete cascade,
    primary key (member_id, recipient_id)
);

create unique index if not exists care_circle_members_active_identity
    on public.care_circle_members (circle_id, user_id)
    where active and user_id is not null;

alter table public.care_invitations enable row level security;
alter table public.care_invitation_recipients enable row level security;
alter table public.member_recipient_access enable row level security;

create or replace function public.is_active_circle_member(circle_id_value uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.care_circle_members member
        where member.circle_id = circle_id_value
          and member.user_id = auth.uid()
          and member.active
    );
$$;

create or replace function public.can_access_recipient(recipient_id_value uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.care_circle_members member
        join public.care_recipients recipient on recipient.circle_id = member.circle_id
        left join public.member_recipient_access access
          on access.member_id = member.id
         and access.recipient_id = recipient.id
        where member.user_id = auth.uid()
          and member.active
          and recipient.id = recipient_id_value
          and (
              member.role in ('owner', 'family')
              or access.recipient_id is not null
          )
    );
$$;

create or replace function public.create_initial_care_setup(
    recipient_name_value text,
    recipient_label_value text,
    recipient_age_value integer,
    relationship_value text,
    display_name_value text
)
returns table (
    circle_id uuid,
    recipient_id uuid,
    family_invite_code text,
    helper_invite_code text
)
language plpgsql
security definer
set search_path = public
as $$
declare
    new_circle_id uuid := gen_random_uuid();
    new_recipient_id uuid := gen_random_uuid();
    new_member_id uuid := gen_random_uuid();
    new_family_code text := upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 8));
    new_helper_code text := upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 8));
    family_invitation_id uuid;
    helper_invitation_id uuid;
begin
    if auth.uid() is null then
        raise exception 'Authentication is required';
    end if;

    insert into public.profiles (id, display_name)
    values (auth.uid(), trim(display_name_value))
    on conflict (id) do update set display_name = excluded.display_name;

    insert into public.care_circles (id, owner_id, name)
    values (new_circle_id, auth.uid(), trim(display_name_value) || '''s Care Circle');

    insert into public.care_recipients (
        id, circle_id, name, label, age, relationship, last_updated
    ) values (
        new_recipient_id,
        new_circle_id,
        trim(recipient_name_value),
        trim(recipient_label_value),
        recipient_age_value,
        trim(relationship_value),
        now()
    );

    insert into public.care_circle_members (
        id, circle_id, recipient_id, user_id, name, role, permission, active, joined_at
    ) values (
        new_member_id,
        new_circle_id,
        null,
        auth.uid(),
        trim(display_name_value),
        'owner',
        'Full access',
        true,
        now()
    );

    insert into public.member_recipient_access (member_id, recipient_id)
    values (new_member_id, new_recipient_id);

    insert into public.care_invitations (
        code, invitation_type, target_role, permission_level, circle_id, created_by
    ) values (
        new_family_code, 'family', 'family', 'Monitor and respond', new_circle_id, auth.uid()
    ) returning id into family_invitation_id;

    insert into public.care_invitations (
        code, invitation_type, target_role, permission_level, circle_id, created_by
    ) values (
        new_helper_code, 'helper', 'helper', 'Assigned care tasks', new_circle_id, auth.uid()
    ) returning id into helper_invitation_id;

    insert into public.care_invitation_recipients (invitation_id, recipient_id)
    values
        (family_invitation_id, new_recipient_id),
        (helper_invitation_id, new_recipient_id);

    insert into public.activity_events (
        id, recipient_id, actor, action, detail, created_at
    ) values (
        gen_random_uuid(),
        new_recipient_id,
        trim(display_name_value),
        'Created care setup',
        'Created the care circle, first recipient and owner membership.',
        now()
    );

    return query select new_circle_id, new_recipient_id, new_family_code, new_helper_code;
end;
$$;

create or replace function public.redeem_care_invitation(
    invite_code_value text,
    expected_type_value text,
    display_name_value text
)
returns table (circle_id uuid, invite_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
    invitation public.care_invitations%rowtype;
    membership_id uuid;
    audit_recipient_id uuid;
begin
    if auth.uid() is null then
        raise exception 'Authentication is required';
    end if;

    select *
      into invitation
      from public.care_invitations
     where code = upper(trim(invite_code_value))
     for update;

    if not found
       or not invitation.active
       or invitation.revoked_at is not null
       or (invitation.expires_at is not null and invitation.expires_at <= now())
       or invitation.invitation_type <> expected_type_value then
        raise exception 'Invitation is invalid, expired, revoked, or has the wrong type';
    end if;

    insert into public.care_circle_members (
        id, circle_id, recipient_id, user_id, name, role, permission, active, joined_at
    ) values (
        gen_random_uuid(),
        invitation.circle_id,
        null,
        auth.uid(),
        trim(display_name_value),
        invitation.target_role,
        invitation.permission_level,
        true,
        now()
    )
    on conflict (circle_id, user_id) where active and user_id is not null
    do update set
        name = excluded.name,
        role = excluded.role,
        permission = excluded.permission,
        active = true
    returning id into membership_id;

    insert into public.member_recipient_access (member_id, recipient_id)
    select membership_id, grant_row.recipient_id
      from public.care_invitation_recipients grant_row
     where grant_row.invitation_id = invitation.id
    on conflict do nothing;

    update public.care_invitations
       set redeemed_at = coalesce(redeemed_at, now()),
           redeemed_by = coalesce(redeemed_by, auth.uid())
     where id = invitation.id;

    select grant_row.recipient_id
      into audit_recipient_id
      from public.care_invitation_recipients grant_row
     where grant_row.invitation_id = invitation.id
     limit 1;

    if audit_recipient_id is not null then
        insert into public.activity_events (
            id, recipient_id, actor, action, detail, created_at
        ) values (
            gen_random_uuid(),
            audit_recipient_id,
            trim(display_name_value),
            'Redeemed invitation',
            'Redeemed a ' || invitation.invitation_type || ' invitation.',
            now()
        );
    end if;

    return query select invitation.circle_id, invitation.code;
end;
$$;

revoke all on function public.create_initial_care_setup(text, text, integer, text, text) from public;
revoke all on function public.redeem_care_invitation(text, text, text) from public;
grant execute on function public.create_initial_care_setup(text, text, integer, text, text) to authenticated;
grant execute on function public.redeem_care_invitation(text, text, text) to authenticated;

drop policy if exists "Members can read their recipient grants" on public.member_recipient_access;
create policy "Members can read their recipient grants"
on public.member_recipient_access
for select
to authenticated
using (
    exists (
        select 1
        from public.care_circle_members member
        where member.id = member_id
          and member.user_id = auth.uid()
          and member.active
    )
);

-- Invitation rows and grants intentionally have no direct client write policy.
-- Creation, validation and redemption occur through security-definer RPCs.
