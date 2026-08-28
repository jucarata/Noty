-- Reminders: qué recordar, en qué devices suena, y cómo respondieron.
-- Tablas, RLS de lectura y RPC create_reminder.
-- Apply in the Supabase SQL editor if the CLI is not linked to the project.

-- ---------------------------------------------------------------------------
-- reminders
-- ---------------------------------------------------------------------------

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  time_local time not null,
  timezone text not null default 'America/Bogota',
  start_date date not null,
  every_day boolean not null default true,
  monday boolean not null default false,
  tuesday boolean not null default false,
  wednesday boolean not null default false,
  thursday boolean not null default false,
  friday boolean not null default false,
  saturday boolean not null default false,
  sunday boolean not null default false,
  run_days integer,
  single_use boolean not null default false,
  is_active boolean not null default true,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint reminders_name_not_blank check (length(trim(name)) > 0),
  constraint reminders_timezone_not_blank check (length(trim(timezone)) > 0),
  constraint reminders_run_days_positive check (run_days is null or run_days > 0),
  constraint reminders_has_schedule check (
    single_use
    or every_day
    or monday
    or tuesday
    or wednesday
    or thursday
    or friday
    or saturday
    or sunday
  ),
  constraint reminders_single_use_exclusive check (
    not single_use
    or (
      every_day = false
      and monday = false
      and tuesday = false
      and wednesday = false
      and thursday = false
      and friday = false
      and saturday = false
      and sunday = false
      and run_days is null
    )
  )
);

comment on table public.reminders is
  'Recordatorio. Suena a time_local en timezone (IANA) desde start_date. single_use excluye every_day, lun–dom y run_days. every_day manda sobre los días. is_active = si debe sonar. Soft delete: deleted_at.';
comment on column public.reminders.name is
  'Título visible. Ej. Tomar Losartan.';
comment on column public.reminders.description is
  'Detalle opcional. Ej. Tomar Losartan 500 mg.';
comment on column public.reminders.time_local is
  'Hora de pared, sin fecha. Ej. 08:00:00.';
comment on column public.reminders.timezone is
  'Zona IANA. Default America/Bogota. No es el nombre del país.';
comment on column public.reminders.start_date is
  'Día civil en que empieza a sonar (no es la hora). Casi siempre el día de creación; puede ser otro. El conteo de run_days y el disparo de single_use arrancan aquí.';
comment on column public.reminders.every_day is
  'Si true, suena todos los días a time_local. Los flags lun–dom no cuentan. Incompatible con single_use.';
comment on column public.reminders.monday is
  'Suena el lunes. Ignorado si every_day o single_use.';
comment on column public.reminders.tuesday is
  'Suena el martes. Ignorado si every_day o single_use.';
comment on column public.reminders.wednesday is
  'Suena el miércoles. Ignorado si every_day o single_use.';
comment on column public.reminders.thursday is
  'Suena el jueves. Ignorado si every_day o single_use.';
comment on column public.reminders.friday is
  'Suena el viernes. Ignorado si every_day o single_use.';
comment on column public.reminders.saturday is
  'Suena el sábado. Ignorado si every_day o single_use.';
comment on column public.reminders.sunday is
  'Suena el domingo. Ignorado si every_day o single_use.';
comment on column public.reminders.run_days is
  'Hasta cuántos días de alarma desde start_date (cada día marcado cuenta 1; una vez por día a time_local). Solo lunes y 7 = el 7º lunes es el último. Lun+mar y 10 = 10 días de alarma, termina el martes de la 5ª semana. Al cumplirse, is_active pasa a false (no aplica si every_day, salvo que run_days esté definido). Null si single_use o si no termina.';
comment on column public.reminders.single_use is
  'Si true, suena una sola vez a time_local en start_date (o el siguiente hueco si la hora ya pasó). Excluye every_day, lun–dom y run_days. Tras sonar, is_active pasa a false.';
comment on column public.reminders.is_active is
  'Si debe sonar. Default true. Con días concretos, al terminar run_days pasa a false y hay que reactivar. Si single_use, tras la única vez pasa a false. Si every_day, sigue true hasta que alguien la desactive.';
comment on column public.reminders.created_by is
  'Profile que creó el recordatorio (hoy el host). No confundir con families.host_id.';
comment on column public.reminders.deleted_at is
  'Null = vigente. Soft delete; no hay columna is_deleted.';

create index reminders_created_by_idx on public.reminders (created_by);
create index reminders_active_idx
  on public.reminders (created_by)
  where deleted_at is null;

create trigger reminders_set_updated_at
  before update on public.reminders
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- reminder_devices
-- ---------------------------------------------------------------------------

create table public.reminder_devices (
  id uuid primary key default gen_random_uuid(),
  reminder_id uuid not null references public.reminders (id) on delete cascade,
  device_id uuid not null references public.devices (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint reminder_devices_once unique (reminder_id, device_id)
);

comment on table public.reminder_devices is
  'En qué teléfonos suena un recordatorio. device_id = devices.id, no install_id.';
comment on column public.reminder_devices.device_id is
  'PK interno de devices. El teléfono se reconoce en runtime por devices.install_id.';

create index reminder_devices_reminder_id_idx
  on public.reminder_devices (reminder_id);
create index reminder_devices_device_id_idx
  on public.reminder_devices (device_id);

-- ---------------------------------------------------------------------------
-- reminder_responses
-- ---------------------------------------------------------------------------

create table public.reminder_responses (
  id uuid primary key default gen_random_uuid(),
  reminder_id uuid not null references public.reminders (id) on delete cascade,
  device_id uuid not null references public.devices (id) on delete cascade,
  response text not null check (response in ('confirmed', 'ignored')),
  due_at timestamptz not null,
  responded_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reminder_responses_once unique (reminder_id, device_id, due_at)
);

comment on table public.reminder_responses is
  'Respuesta del usuario a una ocurrencia: confirmed o ignored. Sin fila = todavía no hay respuesta. No hay missed ni error.';
comment on column public.reminder_responses.device_id is
  'Teléfono que respondió (devices.id). No install_id.';
comment on column public.reminder_responses.response is
  'confirmed: hizo la tarea. ignored: la descartó o indicó que no.';
comment on column public.reminder_responses.due_at is
  'Instante en que debía sonar esa ocurrencia (time_local + timezone de ese día).';
comment on column public.reminder_responses.responded_at is
  'Cuándo pulsó confirmar o ignorar.';

create index reminder_responses_reminder_id_idx
  on public.reminder_responses (reminder_id);
create index reminder_responses_device_id_idx
  on public.reminder_responses (device_id);
create index reminder_responses_due_at_idx
  on public.reminder_responses (reminder_id, due_at);

create trigger reminder_responses_set_updated_at
  before update on public.reminder_responses
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- El host/cuidador solo asigna teléfonos acompañados de sus familias.
-- ---------------------------------------------------------------------------

create or replace function public.is_carer_of_accompanied_device(p_device_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members accompanied
    join public.family_members carer
      on carer.family_id = accompanied.family_id
    where accompanied.device_id = p_device_id
      and accompanied.role = 'accompanied'
      and carer.profile_id = auth.uid()
      and carer.role in ('host', 'caregiver')
  );
$$;

create or replace function public.can_read_reminder(p_reminder_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.reminders r
    where r.id = p_reminder_id
      and r.deleted_at is null
      and (
        r.created_by = auth.uid()
        or exists (
          select 1
          from public.reminder_devices rd
          join public.devices d on d.id = rd.device_id
          where rd.reminder_id = r.id
            and d.owner_id = auth.uid()
        )
        or exists (
          select 1
          from public.reminder_devices rd
          join public.family_members fm on fm.device_id = rd.device_id
          where rd.reminder_id = r.id
            and public.is_family_member(fm.family_id)
        )
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- RPC: crea reminders + reminder_devices en una sola transacción.
-- ---------------------------------------------------------------------------

create or replace function public.create_reminder(
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
  created public.reminders;
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
  if auth.uid() is null then
    raise exception 'Debes entrar a la app para guardar un recordatorio.';
  end if;

  if public.is_anonymous_user() then
    raise exception 'Inicia sesión para guardar un recordatorio.';
  end if;

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

  insert into public.reminders (
    name,
    description,
    time_local,
    timezone,
    start_date,
    every_day,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
    run_days,
    single_use,
    created_by
  )
  values (
    v_name,
    v_description,
    p_time_local,
    v_timezone,
    p_start_date,
    v_every_day,
    v_monday,
    v_tuesday,
    v_wednesday,
    v_thursday,
    v_friday,
    v_saturday,
    v_sunday,
    v_run_days,
    p_single_use,
    auth.uid()
  )
  returning * into created;

  insert into public.reminder_devices (reminder_id, device_id)
  select created.id, distinct_id
  from (
    select distinct d as distinct_id
    from unnest(p_device_ids) as d
  ) as devices;

  return created;
end;
$$;

comment on function public.create_reminder(
  text, time, text, date, uuid[], text, boolean, boolean,
  boolean, boolean, boolean, boolean, boolean, boolean, boolean, integer
) is
  'Crea un recordatorio y lo asigna a devices acompañados de las familias de quien llama (host/caregiver). No anónimos.';

-- ---------------------------------------------------------------------------
-- RLS: leer si lo creaste, suena en tu teléfono, o compartes familia.
-- Mutar reminders / reminder_devices solo por create_reminder.
-- ---------------------------------------------------------------------------

alter table public.reminders enable row level security;
alter table public.reminder_devices enable row level security;
alter table public.reminder_responses enable row level security;

create policy reminders_select_related
  on public.reminders
  for select
  to authenticated
  using (public.can_read_reminder(id));

create policy reminder_devices_select_related
  on public.reminder_devices
  for select
  to authenticated
  using (public.can_read_reminder(reminder_id));

create policy reminder_responses_select_related
  on public.reminder_responses
  for select
  to authenticated
  using (public.can_read_reminder(reminder_id));

revoke all on function public.create_reminder(
  text, time, text, date, uuid[], text, boolean, boolean,
  boolean, boolean, boolean, boolean, boolean, boolean, boolean, integer
) from public;
grant execute on function public.create_reminder(
  text, time, text, date, uuid[], text, boolean, boolean,
  boolean, boolean, boolean, boolean, boolean, boolean, boolean, integer
) to authenticated;

grant select on public.reminders to authenticated;
grant select on public.reminder_devices to authenticated;
grant select on public.reminder_responses to authenticated;
