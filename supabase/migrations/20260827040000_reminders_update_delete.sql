-- Editar y eliminar recordatorios. Soft delete + se desvinculan los devices.
-- Apply in the Supabase SQL editor if the CLI is not linked to the project.

create or replace function public.owned_active_reminder(p_id uuid)
returns public.reminders
language plpgsql
security definer
set search_path = public
as $$
declare
  found public.reminders;
begin
  if auth.uid() is null then
    raise exception 'Debes entrar a la app para gestionar recordatorios.';
  end if;

  if public.is_anonymous_user() then
    raise exception 'Inicia sesión para gestionar recordatorios.';
  end if;

  select *
  into found
  from public.reminders
  where id = p_id
    and deleted_at is null
    and created_by = auth.uid();

  if found.id is null then
    raise exception 'No encontramos este recordatorio.';
  end if;

  return found;
end;
$$;

create or replace function public.update_reminder(
  p_id uuid,
  p_name text,
  p_time_local time,
  p_timezone text,
  p_start_date date,
  p_device_ids uuid[],
  p_description text default null,
  p_single_use boolean default false,
  p_every_day boolean default false,
  p_monday boolean default false,
  p_tuesday boolean default false,
  p_wednesday boolean default false,
  p_thursday boolean default false,
  p_friday boolean default false,
  p_saturday boolean default false,
  p_sunday boolean default false,
  p_run_days integer default null
)
returns public.reminders
language plpgsql
security definer
set search_path = public
as $$
declare
  updated public.reminders;
  device_id uuid;
  v_name text;
  v_description text;
  v_timezone text;
  v_every_day boolean;
  v_monday boolean;
  v_tuesday boolean;
  v_wednesday boolean;
  v_thursday boolean;
  v_friday boolean;
  v_saturday boolean;
  v_sunday boolean;
  v_run_days integer;
begin
  perform public.owned_active_reminder(p_id);

  v_name := trim(p_name);
  if v_name is null or length(v_name) = 0 then
    raise exception 'Ponle un nombre a este recordatorio.';
  end if;

  v_description := nullif(trim(coalesce(p_description, '')), '');
  v_timezone := coalesce(nullif(trim(p_timezone), ''), 'America/Bogota');

  if p_time_local is null then
    raise exception 'Elige la hora de este recordatorio.';
  end if;

  if p_start_date is null then
    raise exception 'Elige el día de inicio.';
  end if;

  if p_device_ids is null or coalesce(array_length(p_device_ids, 1), 0) = 0 then
    raise exception 'Elige al menos un teléfono para este recordatorio.';
  end if;

  if p_single_use then
    v_every_day := false;
    v_monday := false;
    v_tuesday := false;
    v_wednesday := false;
    v_thursday := false;
    v_friday := false;
    v_saturday := false;
    v_sunday := false;
    v_run_days := null;
  elsif p_every_day then
    v_every_day := true;
    v_monday := false;
    v_tuesday := false;
    v_wednesday := false;
    v_thursday := false;
    v_friday := false;
    v_saturday := false;
    v_sunday := false;
    v_run_days := p_run_days;
  else
    v_every_day := false;
    v_monday := coalesce(p_monday, false);
    v_tuesday := coalesce(p_tuesday, false);
    v_wednesday := coalesce(p_wednesday, false);
    v_thursday := coalesce(p_thursday, false);
    v_friday := coalesce(p_friday, false);
    v_saturday := coalesce(p_saturday, false);
    v_sunday := coalesce(p_sunday, false);
    v_run_days := p_run_days;
    if not (
      v_monday or v_tuesday or v_wednesday or v_thursday
      or v_friday or v_saturday or v_sunday
    ) then
      raise exception 'Elige al menos un día de la semana.';
    end if;
  end if;

  if v_run_days is not null and v_run_days <= 0 then
    raise exception 'Los días de ejecución deben ser más de 0.';
  end if;

  for device_id in
    select distinct d
    from unnest(p_device_ids) as d
  loop
    if not public.is_carer_of_accompanied_device(device_id) then
      raise exception 'Ese teléfono no está en tu familia.';
    end if;
  end loop;

  update public.reminders
  set
    name = v_name,
    description = v_description,
    time_local = p_time_local,
    timezone = v_timezone,
    start_date = p_start_date,
    every_day = v_every_day,
    monday = v_monday,
    tuesday = v_tuesday,
    wednesday = v_wednesday,
    thursday = v_thursday,
    friday = v_friday,
    saturday = v_saturday,
    sunday = v_sunday,
    run_days = v_run_days,
    single_use = p_single_use
  where id = p_id
  returning * into updated;

  delete from public.reminder_devices
  where reminder_id = p_id;

  insert into public.reminder_devices (reminder_id, device_id)
  select p_id, distinct_id
  from (
    select distinct d as distinct_id
    from unnest(p_device_ids) as d
  ) as devices;

  return updated;
end;
$$;

create or replace function public.delete_reminder(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.owned_active_reminder(p_id);

  update public.reminders
  set
    deleted_at = now(),
    is_active = false
  where id = p_id;

  delete from public.reminder_devices
  where reminder_id = p_id;
end;
$$;

comment on function public.update_reminder(
  uuid, text, time, text, date, uuid[], text, boolean, boolean,
  boolean, boolean, boolean, boolean, boolean, boolean, boolean, integer
) is
  'Actualiza un recordatorio propio y reemplaza sus reminder_devices.';

comment on function public.delete_reminder(uuid) is
  'Soft delete: deleted_at y se quitan todos los reminder_devices.';

revoke all on function public.owned_active_reminder(uuid) from public;
revoke all on function public.update_reminder(
  uuid, text, time, text, date, uuid[], text, boolean, boolean,
  boolean, boolean, boolean, boolean, boolean, boolean, boolean, integer
) from public;
revoke all on function public.delete_reminder(uuid) from public;
grant execute on function public.update_reminder(
  uuid, text, time, text, date, uuid[], text, boolean, boolean,
  boolean, boolean, boolean, boolean, boolean, boolean, boolean, integer
) to authenticated;
grant execute on function public.delete_reminder(uuid) to authenticated;
