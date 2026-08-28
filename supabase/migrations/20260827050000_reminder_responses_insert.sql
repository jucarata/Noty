-- Responder a una ocurrencia de recordatorio (confirmar o ignorar).
-- Solo el dueño del device que suena puede responder.

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
  where d.owner_id = auth.uid()
  order by d.last_seen_at desc nulls last
  limit 1;

  if v_device_id is null then
    raise exception 'No encontramos este dispositivo.';
  end if;

  if not exists (
    select 1
    from public.reminder_devices rd
    where rd.reminder_id = p_reminder_id
      and rd.device_id = v_device_id
  ) then
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
  do update set
    response = excluded.response,
    responded_at = excluded.responded_at
  returning * into created;

  return created;
end;
$$;

comment on function public.respond_to_reminder(uuid, timestamptz, text) is
  'Confirma o ignora una ocurrencia. due_at = instante en que debía sonar.';

revoke all on function public.respond_to_reminder(uuid, timestamptz, text) from public;
grant execute on function public.respond_to_reminder(uuid, timestamptz, text) to authenticated;

create policy reminder_responses_insert_own_device
  on public.reminder_responses
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.devices d
      where d.id = device_id
        and d.owner_id = auth.uid()
    )
    and public.can_read_reminder(reminder_id)
  );

grant insert on public.reminder_responses to authenticated;
