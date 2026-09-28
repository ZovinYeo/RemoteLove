alter table public.appointments
    add column if not exists reminder_enabled boolean not null default true,
    add column if not exists reminder_days_before integer not null default 3,
    add column if not exists reminder_count integer not null default 1;

alter table public.appointments
    drop constraint if exists appointments_reminder_days_before_check,
    add constraint appointments_reminder_days_before_check
        check (reminder_days_before between 1 and 30);

alter table public.appointments
    drop constraint if exists appointments_reminder_count_check,
    add constraint appointments_reminder_count_check
        check (reminder_count between 1 and 8);

update public.appointments
set
    reminder_enabled = remind_three_days_before,
    reminder_days_before = 3,
    reminder_count = 1
where reminder_enabled is distinct from remind_three_days_before;
