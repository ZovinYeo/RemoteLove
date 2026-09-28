-- Prevent family and helper invitation codes from being redeemed as the other role.

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

revoke all on function public.redeem_care_invitation(text, text, text) from public;
grant execute on function public.redeem_care_invitation(text, text, text) to authenticated;
