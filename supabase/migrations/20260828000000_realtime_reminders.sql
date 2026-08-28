-- Habilita Realtime en tablas de recordatorios (sync al padre crear/editar/borrar).
-- Sin esto, la suscripción del cliente nunca recibe eventos.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'reminders'
  ) then
    alter publication supabase_realtime add table public.reminders;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'reminder_devices'
  ) then
    alter publication supabase_realtime add table public.reminder_devices;
  end if;
end;
$$;
