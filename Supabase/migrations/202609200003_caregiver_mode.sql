alter table public.care_circles
    add column if not exists caregiver_mode text not null default 'helper_only';

alter table public.care_circles
    drop constraint if exists care_circles_caregiver_mode_check,
    add constraint care_circles_caregiver_mode_check
        check (caregiver_mode in ('helper_only', 'family_only', 'both'));

update public.care_circles
set caregiver_mode = 'both'
where id = '00000000-0000-0000-0000-000000000047';

drop function if exists public.create_initial_care_setup(text, text, integer, text, text);

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

grant execute on function public.create_initial_care_setup(text, text, integer, text, text, text) to authenticated;
