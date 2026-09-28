-- RemoteLove care-plan trials.
-- Adds 3-day trial support to care-circle entitlements.

do $$
begin
    if exists (
        select 1
        from pg_constraint
        where conname = 'care_circle_entitlements_status_check'
          and conrelid = 'public.care_circle_entitlements'::regclass
    ) then
        alter table public.care_circle_entitlements
        drop constraint care_circle_entitlements_status_check;
    end if;
end;
$$;

alter table public.care_circle_entitlements
add constraint care_circle_entitlements_status_check
check (status in ('active', 'trialing', 'inactive', 'expired', 'revoked'));
