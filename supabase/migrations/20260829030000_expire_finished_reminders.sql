-- Al terminar el calendario (uso único o último run_days), is_active
-- queda en false y no se reactiva.
-- Responder usa el device propio asignado a ese recordatorio.
-- Realtime en reminder_responses para que quien cuida vea la confirmación.

create or replace function public.reminder_is_alarm_day(
  r public.reminders,
  p_day date
)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    case
      when p_day < r.start_date then false
      when r.single_use then p_day = r.start_date
      when r.every_day then true
      else
        case extract(isodow from p_day)::integer
          when 1 then r.monday
          when 2 then r.tuesday
          when 3 then r.wednesday
          when 4 then r.thursday
          when 5 then r.friday
          when 6 then r.saturday
          when 7 then r.sunday
          else false
        end
    end;
$$;

create or replace function public.reminder_alarm_count_through(
  r public.reminders,
  p_day date
)
returns integer
language sql
stable
set search_path = public
as $$
  select count(*)::integer
  from generate_series(r.start_date, p_day, interval '1 day') as gs(d)
  where public.reminder_is_alarm_day(r, gs.d::date);
$$;

create or replace function public.reminder_next_scheduled_at(
  r public.reminders,
  p_from timestamptz
)
returns timestamptz
language plpgsql
stable
set search_path = public
as $$
declare
  v_tz text;
  v_local timestamp;
  v_today date;
  v_cursor date;
  v_ring timestamp;
  v_ring_at timestamptz;
begin
  v_tz := coalesce(nullif(trim(r.timezone), ''), 'America/Bogota');
  v_local := p_from at time zone v_tz;
  v_today := v_local::date;
  v_cursor := greatest(v_today, r.start_date);

  for i in 1..800 loop
    if public.reminder_is_alarm_day(r, v_cursor)
      and (
        r.run_days is null
        or public.reminder_alarm_count_through(r, v_cursor) <= r.run_days
      )
    then
      v_ring := v_cursor + r.time_local;
      v_ring_at := v_ring at time zone v_tz;
      if v_cursor <> v_today or v_ring_at > p_from then
        return v_ring_at;
      end if;
    end if;

    if r.run_days is not null
      and public.reminder_alarm_count_through(r, v_cursor) >= r.run_days
    then
      return null;
    end if;

    v_cursor := v_cursor + 1;
  end loop;

  return null;
end;
$$;

create or replace function public.expire_finished_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  update public.reminders r
  set is_active = false
  where r.deleted_at is null
    and r.is_active
    and public.can_read_reminder(r.id)
    and public.reminder_next_scheduled_at(r, now()) is null;
end;
$$;

comment on function public.expire_finished_reminders() is
  'Pone is_active = false en recordatorios que ya no tienen más avisos. No se reactiva.';

create or replace function public.respond_to_reminder(
  p_reminder_id uuid,
  p_due_at timestamptz,
  p_response text
)
returns public.reminder_responses
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device_id uuid;
  v_response text;
  created public.reminder_responses;
begin
  if auth.uid() is null then
    raise exception 'Debes entrar a la app para responder.';
  end if;

  v_response := lower(trim(p_response));
  if v_response not in ('confirmed', 'ignored') then
    raise exception 'Respuesta no válida.';
  end if;

  select d.id
  into v_device_id
  from public.devices d
  join public.reminder_devices rd on rd.device_id = d.id
  where d.owner_id = auth.uid()
    and rd.reminder_id = p_reminder_id
  order by d.last_seen_at desc nulls last
  limit 1;

  if v_device_id is null then
    raise exception 'Este recordatorio no suena en este teléfono.';
  end if;

  if not public.can_read_reminder(p_reminder_id) then
    raise exception 'No puedes responder a este recordatorio.';
  end if;

  insert into public.reminder_responses (
    reminder_id,
    device_id,
    response,
    due_at,
    responded_at
  )
  values (
    p_reminder_id,
    v_device_id,
    v_response,
    p_due_at,
    now()
  )
  on conflict (reminder_id, device_id, due_at)
  do nothing
  returning * into created;

  if created is null then
    select *
    into created
    from public.reminder_responses
    where reminder_id = p_reminder_id
      and device_id = v_device_id
      and due_at = p_due_at;
  end if;

  update public.reminders r
  set is_active = false
  where r.id = p_reminder_id
    and r.is_active
    and public.reminder_next_scheduled_at(r, p_due_at) is null;

  return created;
end;
$$;

comment on function public.respond_to_reminder(uuid, timestamptz, text) is
  'Primera respuesta gana (confirmed o ignored). No se puede cambiar. Si era la última ocurrencia, is_active pasa a false.';

revoke all on function public.reminder_is_alarm_day(public.reminders, date) from public;
revoke all on function public.reminder_alarm_count_through(public.reminders, date) from public;
revoke all on function public.reminder_next_scheduled_at(public.reminders, timestamptz) from public;
revoke all on function public.expire_finished_reminders() from public;
revoke all on function public.respond_to_reminder(uuid, timestamptz, text) from public;

grant execute on function public.expire_finished_reminders() to authenticated;
grant execute on function public.respond_to_reminder(uuid, timestamptz, text) to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'reminder_responses'
  ) then
    alter publication supabase_realtime add table public.reminder_responses;
  end if;
end;
$$;
