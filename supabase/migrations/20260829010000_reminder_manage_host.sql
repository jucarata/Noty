-- Editar/eliminar: creador del recordatorio o host de la familia del teléfono.
-- Apply in the Supabase SQL editor if the CLI is not linked to the project.

create or replace function public.is_host_of_reminder(p_reminder_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.reminder_devices rd
    join public.family_members accompanied
      on accompanied.device_id = rd.device_id
     and accompanied.role = 'accompanied'
    join public.family_members host
      on host.family_id = accompanied.family_id
     and host.profile_id = auth.uid()
     and host.role = 'host'
    where rd.reminder_id = p_reminder_id
  );
$$;

comment on function public.is_host_of_reminder(uuid) is
  'True si quien llama es host de una familia cuyo device acompañado está en este recordatorio.';

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
    and (
      created_by = auth.uid()
      or public.is_host_of_reminder(p_id)
    );

  if found.id is null then
    raise exception 'No encontramos este recordatorio.';
  end if;

  return found;
end;
$$;

comment on function public.owned_active_reminder(uuid) is
  'Recordatorio vigente que puede gestionar quien lo creó o el host de la familia.';

comment on function public.update_reminder(
  uuid, text, time, text, date, uuid[], text, boolean, boolean,
  boolean, boolean, boolean, boolean, boolean, boolean, boolean, integer
) is
  'Actualiza un recordatorio del creador o del host de la familia y reemplaza sus reminder_devices.';

revoke all on function public.is_host_of_reminder(uuid) from public;
revoke all on function public.owned_active_reminder(uuid) from public;
