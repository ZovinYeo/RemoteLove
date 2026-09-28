alter table if exists public.medicines
    add column if not exists repeat_weekdays integer[];

notify pgrst, 'reload schema';
