-- Reminders: qué recordar, en qué devices suena, y cómo respondieron.
-- Solo tablas. RLS, RPCs y la app se enganchan después.
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
  ),
  constraint reminders_repeat_needs_run_days check (
    single_use
    or run_days is not null
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
  'Hasta cuántos días de alarma desde start_date (cada día marcado cuenta 1; una vez por día a time_local). Solo lunes y 7 = el 7º lunes es el último. Lun+mar y 10 = 10 días de alarma, termina el martes de la 5ª semana. Al cumplirse, is_active pasa a false (no aplica si every_day). Null si single_use.';
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

alter table public.reminders enable row level security;
alter table public.reminder_devices enable row level security;
alter table public.reminder_responses enable row level security;
