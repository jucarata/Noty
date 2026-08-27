-- Identity and family-care schema for Noty.
-- Apply in the Supabase SQL editor if the CLI is not linked to the project.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_anonymous_user()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'Invitado',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Persona de Noty. id = auth.users.id (correo, Google, Microsoft o anónimo). No usar public.users.';
comment on column public.profiles.display_name is
  'Nombre visible. En anónimos puede ser un apodo o el nombre del dispositivo.';

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  install_id uuid not null unique,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  custom_name text,
  platform text not null check (platform in ('android', 'ios')),
  brand text,
  model text,
  device_kind text not null default 'phone' check (device_kind in ('phone', 'tablet')),
  os_version text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.devices is
  'Un install de la app. Existe con o sin login real. El QR lleva install_id, no el id de hardware del SO.';
comment on column public.devices.install_id is
  'UUID generado por la app y persistido en secure storage. Identidad estable del dispositivo.';
comment on column public.devices.owner_id is
  'Profile que usa este teléfono (anónimo o autenticado). Un profile puede tener varios devices.';
comment on column public.devices.custom_name is
  'Nombre para reconocerlo, p. ej. Celular de la abuela.';

create table public.families (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles (id) on delete restrict,
  name text not null default 'Mi familia',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.families is
  'Grupo familiar. El host es el padre/cuidador que lo creó. Un device puede estar en varias familias.';
comment on column public.families.host_id is
  'Profile no anónimo que creó el grupo.';

create table public.family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  device_id uuid references public.devices (id) on delete cascade,
  role text not null check (role in ('host', 'caregiver', 'accompanied')),
  created_at timestamptz not null default now(),
  constraint family_members_accompanied_needs_device check (
    (role = 'accompanied' and device_id is not null)
    or (role in ('host', 'caregiver') and device_id is null)
  )
);

comment on table public.family_members is
  'Vínculo persona–familia. host/caregiver = padres. accompanied = persona (a menudo anónima) y el device del QR.';
comment on column public.family_members.role is
  'host: dueño del grupo. caregiver: otro padre. accompanied: quien recibe cuidado en ese device.';
comment on column public.family_members.device_id is
  'Obligatorio si role = accompanied (el teléfono que suena). Null en host/caregiver.';

create unique index family_members_one_host
  on public.family_members (family_id)
  where role = 'host';

create unique index family_members_person_carer_once
  on public.family_members (family_id, profile_id)
  where role in ('host', 'caregiver');

create unique index family_members_device_once
  on public.family_members (family_id, device_id)
  where device_id is not null;

create index devices_owner_id_idx on public.devices (owner_id);
create index families_host_id_idx on public.families (host_id);
create index family_members_family_id_idx on public.family_members (family_id);
create index family_members_profile_id_idx on public.family_members (profile_id);
create index family_members_device_id_idx on public.family_members (device_id);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger devices_set_updated_at
  before update on public.devices
  for each row execute function public.set_updated_at();

create trigger families_set_updated_at
  before update on public.families
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Auth → profile
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  chosen_name text;
begin
  chosen_name := coalesce(
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'name', ''),
    nullif(new.email, ''),
    'Invitado'
  );

  insert into public.profiles (id, display_name)
  values (new.id, chosen_name)
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- RLS helpers (security definer to avoid recursive policies)
-- ---------------------------------------------------------------------------

create or replace function public.is_family_member(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members
    where family_id = p_family_id
      and profile_id = auth.uid()
  );
$$;

create or replace function public.is_family_carer(p_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members
    where family_id = p_family_id
      and profile_id = auth.uid()
      and role in ('host', 'caregiver')
  );
$$;

create or replace function public.shares_family_with(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members me
    join public.family_members them
      on them.family_id = me.family_id
    where me.profile_id = auth.uid()
      and them.profile_id = p_profile_id
  );
$$;

-- ---------------------------------------------------------------------------
-- RPCs: crear familia y vincular device (el padre escanea el QR)
-- ---------------------------------------------------------------------------

create or replace function public.create_family(p_name text default 'Mi familia')
returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  created public.families;
begin
  if auth.uid() is null then
    raise exception 'Debes entrar a la app para crear un grupo familiar.';
  end if;

  if public.is_anonymous_user() then
    raise exception 'Inicia sesión para crear un grupo familiar.';
  end if;

  insert into public.families (host_id, name)
  values (auth.uid(), coalesce(nullif(trim(p_name), ''), 'Mi familia'))
  returning * into created;

  insert into public.family_members (family_id, profile_id, device_id, role)
  values (created.id, auth.uid(), null, 'host');

  return created;
end;
$$;

create or replace function public.link_device_to_family(
  p_install_id uuid,
  p_family_id uuid default null
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

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.families enable row level security;
alter table public.family_members enable row level security;

create policy profiles_select_own_or_family
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid() or public.shares_family_with(id));

create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy devices_select_own_or_family
  on public.devices
  for select
  to authenticated
  using (
    owner_id = auth.uid()
    or exists (
      select 1
      from public.family_members fm
      where fm.device_id = devices.id
        and public.is_family_member(fm.family_id)
    )
  );

create policy devices_insert_own
  on public.devices
  for insert
  to authenticated
  with check (owner_id = auth.uid());

create policy devices_update_own
  on public.devices
  for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy families_select_member
  on public.families
  for select
  to authenticated
  using (public.is_family_member(id));

create policy families_update_host
  on public.families
  for update
  to authenticated
  using (host_id = auth.uid())
  with check (host_id = auth.uid());

create policy family_members_select_same_family
  on public.family_members
  for select
  to authenticated
  using (public.is_family_member(family_id));

-- Mutations of families / family_members go through create_family and
-- link_device_to_family (security definer). No direct insert policies.

revoke all on function public.create_family(text) from public;
revoke all on function public.link_device_to_family(uuid, uuid) from public;
grant execute on function public.create_family(text) to authenticated;
grant execute on function public.link_device_to_family(uuid, uuid) to authenticated;

grant select, update on public.profiles to authenticated;
grant select, insert, update on public.devices to authenticated;
grant select, update on public.families to authenticated;
grant select on public.family_members to authenticated;
