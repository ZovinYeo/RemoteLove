-- Force-seed the RemoteLove shared demo after deploying 202609180003.
-- Run this in Supabase SQL Editor if demo_profiles still returns 0.

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
        raise exception 'No Supabase auth users exist yet. Create/sign in one user first, then run this seed.';
    end if;

    perform public.seed_remote_love_demo_data(seed_owner);
end;
$$;

notify pgrst, 'reload schema';
