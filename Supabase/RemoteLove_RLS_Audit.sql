-- RemoteLove RLS Audit
-- Run this in Supabase SQL Editor.
-- This script is read-only: it reports security posture and does not change data or policies.

-- 1) RLS status for RemoteLove tables.
select
    '01_rls_status' as audit_section,
    c.relname as table_name,
    case
        when c.relrowsecurity then 'PASS'
        else 'REVIEW: RLS is not enabled'
    end as result,
    case when c.relrowsecurity then 'YES' else 'NO' end as row_security
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
      'profiles',
      'care_circles',
      'care_circle_entitlements',
      'care_circle_invites',
      'care_recipients',
      'care_circle_members',
      'care_tasks',
      'medicines',
      'appointments',
      'planner_other_items',
      'health_logs',
      'care_updates',
      'activity_events'
  )
order by table_name;

-- 2) Full policy listing.
select
    '02_policy_inventory' as audit_section,
    tablename,
    policyname,
    cmd,
    roles,
    qual as using_expression,
    with_check as with_check_expression
from pg_policies
where schemaname = 'public'
  and tablename in (
      'profiles',
      'care_circles',
      'care_circle_entitlements',
      'care_circle_invites',
      'care_recipients',
      'care_circle_members',
      'care_tasks',
      'medicines',
      'appointments',
      'planner_other_items',
      'health_logs',
      'care_updates',
      'activity_events'
  )
order by tablename, policyname;

-- 3) Policies that look broadly permissive.
select
    '03_risky_policy_patterns' as audit_section,
    tablename,
    policyname,
    cmd,
    roles,
    qual as using_expression,
    with_check as with_check_expression,
    'REVIEW: policy may be too broad' as result
from pg_policies
where schemaname = 'public'
  and (
      qual in ('true', '(true)')
      or with_check in ('true', '(true)')
      or roles::text ilike '%anon%'
      or (
          coalesce(qual, '') not ilike '%auth.uid%'
          and coalesce(qual, '') not ilike '%is_care_circle_member%'
          and coalesce(qual, '') not ilike '%can_access_recipient%'
      )
  )
order by tablename, policyname;

-- 4) Tables with RLS enabled but no policies.
select
    '04_rls_enabled_without_policies' as audit_section,
    c.relname as table_name,
    'REVIEW: RLS enabled but no policies found' as result
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_policy p on p.polrelid = c.oid
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relrowsecurity = true
  and c.relname in (
      'profiles',
      'care_circles',
      'care_circle_entitlements',
      'care_circle_invites',
      'care_recipients',
      'care_circle_members',
      'care_tasks',
      'medicines',
      'appointments',
      'planner_other_items',
      'health_logs',
      'care_updates',
      'activity_events'
  )
group by c.relname
having count(p.oid) = 0
order by c.relname;

-- 5) Grants to anon/authenticated for RemoteLove tables.
select
    '05_table_grants' as audit_section,
    table_name,
    grantee,
    privilege_type,
    case
        when grantee = 'anon' then 'REVIEW: anon should not have direct access to care data'
        else 'INFO'
    end as result
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated')
  and table_name in (
      'profiles',
      'care_circles',
      'care_circle_entitlements',
      'care_circle_invites',
      'care_recipients',
      'care_circle_members',
      'care_tasks',
      'medicines',
      'appointments',
      'planner_other_items',
      'health_logs',
      'care_updates',
      'activity_events'
  )
order by table_name, grantee, privilege_type;

-- 6) Security-definer functions and execute grants.
select
    '06_function_security' as audit_section,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    case when p.prosecdef then 'SECURITY DEFINER' else 'SECURITY INVOKER' end as security_mode,
    coalesce(array_to_string(p.proconfig, ', '), '') as function_settings,
    pg_get_function_result(p.oid) as returns
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
      'is_care_circle_member',
      'can_access_recipient',
      'create_care_circle_with_invite',
      'create_initial_care_setup',
      'join_care_circle_with_code',
      'redeem_care_invitation',
      'join_remote_love_demo',
      'seed_remote_love_demo_data',
      'start_care_plan_trial',
      'activate_care_plan',
      'cancel_care_plan'
  )
order by p.proname;

select
    '07_function_execute_grants' as audit_section,
    routine_name,
    grantee,
    privilege_type,
    case
        when grantee = 'anon' then 'REVIEW: anon execute grant should be intentional'
        else 'INFO'
    end as result
from information_schema.routine_privileges
where specific_schema = 'public'
  and grantee in ('anon', 'authenticated')
  and routine_name in (
      'is_care_circle_member',
      'can_access_recipient',
      'create_care_circle_with_invite',
      'create_initial_care_setup',
      'join_care_circle_with_code',
      'redeem_care_invitation',
      'join_remote_love_demo',
      'seed_remote_love_demo_data',
      'start_care_plan_trial',
      'activate_care_plan',
      'cancel_care_plan'
  )
order by routine_name, grantee;

-- 7) Orphan / suspicious data checks.
select
    '08_orphan_tasks' as audit_section,
    count(*) as row_count,
    case when count(*) = 0 then 'PASS' else 'REVIEW: tasks reference missing care recipients' end as result
from public.care_tasks t
left join public.care_recipients r on r.id = t.recipient_id
where r.id is null;

select
    '09_orphan_health_logs' as audit_section,
    count(*) as row_count,
    case when count(*) = 0 then 'PASS' else 'REVIEW: health logs reference missing care recipients' end as result
from public.health_logs h
left join public.care_recipients r on r.id = h.recipient_id
where r.id is null;

select
    '10_orphan_members' as audit_section,
    count(*) as row_count,
    case when count(*) = 0 then 'PASS' else 'REVIEW: members reference missing care circles' end as result
from public.care_circle_members m
left join public.care_circles c on c.id = m.circle_id
where c.id is null;

select
    '11_duplicate_memberships' as audit_section,
    circle_id,
    user_id,
    count(*) as duplicate_count,
    'REVIEW: duplicate active membership for same user/circle' as result
from public.care_circle_members
where user_id is not null
  and active = true
group by circle_id, user_id
having count(*) > 1
order by duplicate_count desc;

-- 8) Invite-code checks.
select
    '12_active_invite_summary' as audit_section,
    invitation_type,
    target_role,
    active,
    count(*) as invite_count
from public.care_circle_invites
group by invitation_type, target_role, active
order by active desc, invitation_type, target_role;

select
    '13_owner_invites' as audit_section,
    id,
    code,
    circle_id,
    target_role,
    invitation_type,
    'REVIEW: invite should never grant Owner role' as result
from public.care_circle_invites
where lower(coalesce(target_role, '')) = 'owner'
   or lower(coalesce(invitation_type, '')) = 'owner';

-- 9) Helper permissions review.
select
    '14_helper_permissions' as audit_section,
    id,
    circle_id,
    recipient_id,
    user_id,
    name,
    role,
    permission,
    permission_level,
    active,
    case
        when lower(coalesce(role, '')) = 'helper'
         and lower(coalesce(permission, permission_level, '')) not like '%task%'
        then 'REVIEW: helper permission does not mention task access'
        else 'INFO'
    end as result
from public.care_circle_members
where lower(coalesce(role, '')) = 'helper'
order by circle_id, name;

-- 10) Manual test checklist.
select
    '15_manual_tests' as audit_section,
    unnest(array[
        'Sign in as Family Owner A. Confirm only Owner A care-circle rows appear.',
        'Sign in as Family Owner B. Confirm Owner A rows do not appear.',
        'Sign in as Helper. Confirm helper sees only joined care circle data.',
        'Helper should not see care plan payment/admin controls.',
        'Unrelated user should not read care_circle_invites for other circles.',
        'User should not insert care_tasks for another circle recipient_id.',
        'Helper should not insert/update care_circle_members to grant owner access.',
        'Invite redemption should happen through RPC, not direct invite browsing.'
    ]) as test_to_perform;
