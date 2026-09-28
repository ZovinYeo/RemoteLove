-- RemoteLove Supabase smoke checks
-- Run after RemoteLoveSchema.sql in Supabase Dashboard > SQL Editor.
-- These checks do not create care data; they only verify helper functions exist.

with function_checks as (
    select count(*) as installed_count
    from information_schema.routines
    where specific_schema = 'public'
    and routine_name in (
        'create_initial_care_setup',
        'redeem_care_invitation',
        'generate_care_invite_code',
        'normalize_invite_code'
    )
),
table_checks as (
    select count(*) as installed_count
    from information_schema.tables
    where table_schema = 'public'
      and table_name in (
          'care_circle_entitlements',
          'planner_other_items'
      )
),
column_checks as (
    select count(*) as installed_count
    from information_schema.columns
    where table_schema = 'public'
      and (
          (table_name = 'care_circles' and column_name = 'health_enabled')
          or (table_name = 'care_circles' and column_name = 'caregiver_mode')
          or (table_name = 'care_circle_entitlements' and column_name = 'current_period_ends_at')
          or (table_name = 'appointments' and column_name = 'reminder_enabled')
          or (table_name = 'appointments' and column_name = 'reminder_days_before')
          or (table_name = 'appointments' and column_name = 'reminder_count')
          or (table_name = 'medicines' and column_name = 'dose_times')
          or (table_name = 'medicines' and column_name = 'repeat_weekdays')
      )
)
select
    'normalize_invite_code' as check_name,
    case when public.normalize_invite_code(' ab-c 123 ') = 'ABC123' then 'pass' else 'fail' end as status,
    public.normalize_invite_code(' ab-c 123 ') as detail
union all
select
    'generate_care_invite_code',
    case when length(public.generate_care_invite_code()) = 8 then 'pass' else 'fail' end,
    public.generate_care_invite_code()
union all
select
    'required_functions_installed',
    case when installed_count = 4 then 'pass' else 'fail' end,
    installed_count::text || ' of 4 functions found'
from function_checks
union all
select
    'latest_tables_installed',
    case when installed_count = 2 then 'pass' else 'fail' end,
    installed_count::text || ' of 2 latest tables found'
from table_checks
union all
select
    'latest_columns_installed',
    case when installed_count = 8 then 'pass' else 'fail' end,
    installed_count::text || ' of 8 latest columns found'
from column_checks;
