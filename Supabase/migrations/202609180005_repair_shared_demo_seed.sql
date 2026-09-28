-- Repair shared demo seeding for LOVE2026.
-- This recreates the demo seed RPC in a minimal, reliable order and seeds the demo immediately.

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
begin
    if owner_id_value is null then
        raise exception 'A demo owner user id is required.';
    end if;

    insert into public.care_circles (id, owner_id, name)
    values (demo_circle_id, owner_id_value, 'RemoteLove Demo Care Circle')
    on conflict (id) do update
    set name = excluded.name;

    insert into public.care_recipients (id, circle_id, name, label, age, relationship, last_updated)
    values
        (mum_id, demo_circle_id, 'Mei Ling', 'Mum', 68, 'Parent', now()),
        (dad_id, demo_circle_id, 'Wei Ming', 'Dad', 72, 'Parent', now())
    on conflict (id) do update
    set circle_id = excluded.circle_id,
        name = excluded.name,
        label = excluded.label,
        age = excluded.age,
        relationship = excluded.relationship;

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
    values (
        'LOVE2026',
        demo_circle_id,
        mum_id,
        owner_id_value,
        true,
        'family',
        'Family',
        'Monitor and respond',
        null,
        0
    )
    on conflict (code) do update
    set circle_id = excluded.circle_id,
        recipient_id = excluded.recipient_id,
        created_by = excluded.created_by,
        active = true,
        invitation_type = 'family',
        target_role = 'Family',
        permission_level = 'Monitor and respond';

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
        demo_circle_id,
        mum_id,
        owner_id_value,
        'Demo Family',
        'Family',
        'Monitor and respond',
        'Monitor and respond',
        true,
        now()
    )
    on conflict do nothing;

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
    on conflict (id) do update
    set display_name = excluded.display_name;

    update public.care_circle_members
    set name = profile_name,
        role = member_role,
        permission = member_permission,
        permission_level = member_permission,
        active = true
    where circle_id = demo_circle_id
      and user_id = current_user_id;

    if not found then
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
            demo_circle_id,
            null,
            current_user_id,
            profile_name,
            member_role,
            member_permission,
            member_permission,
            true,
            now()
        );
    end if;

    return query select demo_circle_id, 'LOVE2026'::text;
end;
$$;

grant execute on function public.seed_remote_love_demo_data(uuid) to authenticated;
grant execute on function public.join_remote_love_demo(text, text) to authenticated;

do $$
declare
    seed_owner uuid;
begin
    select id
    into seed_owner
    from auth.users
    order by created_at
    limit 1;

    if seed_owner is null then
        raise exception 'No Supabase auth users exist yet. Create/sign in one user first, then run this migration again.';
    end if;

    perform public.seed_remote_love_demo_data(seed_owner);
end;
$$;

notify pgrst, 'reload schema';
