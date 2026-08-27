-- TEMPORAL (desarrollo): el usuario autenticado puede borrar su propia cuenta.
-- Quitar cuando exista Profile y deje de hacer falta el botón de pruebas.

create or replace function public.purge_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Debes entrar a la app para borrar esta cuenta.';
  end if;

  -- host_id es RESTRICT: hay que soltar el grupo antes de borrar el profile.
  delete from public.families where host_id = uid;
  delete from auth.users where id = uid;
end;
$$;

comment on function public.purge_own_account() is
  'TEMPORAL de desarrollo: borra la cuenta actual (auth + datos en cascada). No usar en producto.';

revoke all on function public.purge_own_account() from public, anon;
grant execute on function public.purge_own_account() to authenticated;
