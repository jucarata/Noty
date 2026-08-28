-- Registra este teléfono (install_id) para el usuario actual.
-- Evita el upsert directo + RLS: si el install ya existe y es de otra cuenta,
-- la app genera un install_id nuevo. Apply in the SQL editor if CLI is not linked.

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
      custom_name = excluded.custom_name,
      last_seen_at = excluded.last_seen_at
    where public.devices.owner_id = uid
  returning id into device_id;

  if device_id is null then
    raise exception 'Este dispositivo ya está vinculado a otra cuenta.';
  end if;

  return device_id;
end;
$$;

comment on function public.register_own_device(uuid, text, text, text, text, text, text) is
  'Crea o actualiza el device de este install para auth.uid(). No transfiere un install ajeno.';

revoke all on function public.register_own_device(uuid, text, text, text, text, text, text) from public, anon;
grant execute on function public.register_own_device(uuid, text, text, text, text, text, text) to authenticated;
