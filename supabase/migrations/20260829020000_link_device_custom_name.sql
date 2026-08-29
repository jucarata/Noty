-- El host nombra el teléfono al escanear el QR, y puede desvincularlo
-- de su familia. Apply in the SQL editor if the CLI is not linked.

drop function if exists public.link_device_to_family(uuid, uuid);

create or replace function public.link_device_to_family(
  p_install_id uuid,
  p_family_id uuid default null,
  p_custom_name text default null
)
returns public.family_members
language plpgsql
security definer
set search_path = public
as $$
declare
  target_family_id uuid;
  target_device public.devices;
  created public.family_members;
  named text := nullif(trim(p_custom_name), '');
begin
  if auth.uid() is null then
    raise exception 'Debes entrar a la app para vincular un dispositivo.';
  end if;

  if public.is_anonymous_user() then
    raise exception 'Inicia sesión para vincular un dispositivo.';
  end if;

  select *
  into target_device
  from public.devices
  where install_id = p_install_id;

  if target_device.id is null then
    raise exception 'No encontramos ese dispositivo. Pide que vuelva a mostrar el código.';
  end if;

  if p_family_id is not null then
    if not public.is_family_carer(p_family_id) then
      raise exception 'No puedes vincular dispositivos a este grupo familiar.';
    end if;
    target_family_id := p_family_id;
  else
    select id
    into target_family_id
    from public.families
    where host_id = auth.uid()
    order by created_at asc
    limit 1;

    if target_family_id is null then
      target_family_id := (public.create_family('Mi familia')).id;
    end if;
  end if;

  if named is not null then
    update public.devices
    set custom_name = named
    where id = target_device.id;
  end if;

  select *
  into created
  from public.family_members
  where family_id = target_family_id
    and device_id = target_device.id;

  if created.id is not null then
    return created;
  end if;

  insert into public.family_members (family_id, profile_id, device_id, role)
  values (target_family_id, target_device.owner_id, target_device.id, 'accompanied')
  returning * into created;

  return created;
end;
$$;

comment on function public.link_device_to_family(uuid, uuid, text) is
  'Une el device del QR a la familia del host. Si hay p_custom_name, lo guarda en devices.';

revoke all on function public.link_device_to_family(uuid, uuid, text) from public;
grant execute on function public.link_device_to_family(uuid, uuid, text) to authenticated;

-- Conserva el nombre que puso el host si el teléfono se vuelve a registrar.
create or replace function public.register_own_device(
  p_install_id uuid,
  p_platform text,
  p_device_kind text default 'phone',
  p_brand text default null,
  p_model text default null,
  p_os_version text default null,
  p_custom_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  kind text := coalesce(nullif(trim(p_device_kind), ''), 'phone');
  device_id uuid;
begin
  if uid is null then
    raise exception 'Debes entrar a la app para compartir este dispositivo.';
  end if;

  if p_platform not in ('android', 'ios') then
    raise exception 'Plataforma no válida.';
  end if;

  if kind not in ('phone', 'tablet') then
    kind := 'phone';
  end if;

  insert into public.profiles (id, display_name)
  values (uid, 'Invitado')
  on conflict (id) do nothing;

  insert into public.devices (
    install_id,
    owner_id,
    platform,
    device_kind,
    brand,
    model,
    os_version,
    custom_name,
    last_seen_at
  )
  values (
    p_install_id,
    uid,
    p_platform,
    kind,
    nullif(trim(p_brand), ''),
    nullif(trim(p_model), ''),
    nullif(trim(p_os_version), ''),
    nullif(trim(p_custom_name), ''),
    now()
  )
  on conflict (install_id) do update
    set
      platform = excluded.platform,
      device_kind = excluded.device_kind,
      brand = excluded.brand,
      model = excluded.model,
      os_version = excluded.os_version,
      custom_name = coalesce(
        nullif(trim(public.devices.custom_name), ''),
        excluded.custom_name
      ),
      last_seen_at = excluded.last_seen_at
    where public.devices.owner_id = uid
  returning id into device_id;

  if device_id is null then
    raise exception 'Este dispositivo ya está vinculado a otra cuenta.';
  end if;

  return device_id;
end;
$$;

-- Quita un teléfono acompañado de la familia de quien llama y los
-- recordatorios que ese grupo le había asignado.
create or replace function public.unlink_device_from_family(p_device_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_family_ids uuid[];
  affected_reminder_ids uuid[];
begin
  if auth.uid() is null then
    raise exception 'Debes entrar a la app para desvincular un dispositivo.';
  end if;

  if public.is_anonymous_user() then
    raise exception 'Inicia sesión para desvincular un dispositivo.';
  end if;

  if p_device_id is null then
    raise exception 'No encontramos ese familiar en tu grupo.';
  end if;

  select coalesce(array_agg(fm.family_id), '{}')
  into target_family_ids
  from public.family_members fm
  where fm.device_id = p_device_id
    and fm.role = 'accompanied'
    and public.is_family_carer(fm.family_id);

  if coalesce(array_length(target_family_ids, 1), 0) = 0 then
    raise exception 'No encontramos ese familiar en tu grupo.';
  end if;

  select coalesce(array_agg(r.id), '{}')
  into affected_reminder_ids
  from public.reminders r
  join public.reminder_devices rd on rd.reminder_id = r.id
  where rd.device_id = p_device_id
    and r.deleted_at is null
    and (
      r.created_by = auth.uid()
      or exists (
        select 1
        from public.family_members carer
        where carer.family_id = any (target_family_ids)
          and carer.profile_id = r.created_by
          and carer.role in ('host', 'caregiver')
      )
    );

  delete from public.reminder_devices
  where device_id = p_device_id
    and reminder_id = any (affected_reminder_ids);

  update public.reminders
  set
    deleted_at = now(),
    is_active = false
  where id = any (affected_reminder_ids)
    and deleted_at is null
    and not exists (
      select 1
      from public.reminder_devices rd
      where rd.reminder_id = public.reminders.id
    );

  delete from public.family_members
  where device_id = p_device_id
    and role = 'accompanied'
    and family_id = any (target_family_ids);
end;
$$;

comment on function public.unlink_device_from_family(uuid) is
  'Saca el device acompañado de las familias de quien llama y quita los reminder_devices (y recordatorios huérfanos) de ese grupo. No borra el device ni las alarmas de otros padres.';

revoke all on function public.unlink_device_from_family(uuid) from public, anon;
grant execute on function public.unlink_device_from_family(uuid) to authenticated;
