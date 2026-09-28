-- RemoteLove shared demo data.
-- Seeds LOVE2026 into Supabase and lets demo family/helper users join the same care circle.

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
    insert into public.care_circles (id, owner_id, name)
    values (demo_circle_id, owner_id_value, 'RemoteLove Demo Care Circle')
    on conflict (id) do nothing;

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
        id, recipient_id, title, date, notes, repeat_rule, remind_three_days_before, state
    )
    values
        ('40000000-0000-0000-0000-000000000001', mum_id, 'Blood pressure review', today + interval '2 days 10 hours', 'Bring recent readings and medicine list.', 'Does not repeat', true, 'scheduled'),
        ('40000000-0000-0000-0000-000000000002', mum_id, 'Annual health screening', today + interval '14 days 9 hours 30 minutes', 'Routine yearly check-up.', 'Every year', true, 'scheduled'),
        ('40000000-0000-0000-0000-000000000003', dad_id, 'Diabetes review', today + interval '5 days 14 hours', 'Bring glucose log.', 'Every 3 months', true, 'scheduled')
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

notify pgrst, 'reload schema';
