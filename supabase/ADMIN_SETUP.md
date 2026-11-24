# Inicialización del administrador de plataforma

Las acciones del panel comprueban `public.user_roles` en el servidor. No se
incluye un botón en la app para elevar permisos.

Después de revisar y aplicar la migración `202610030001_platform_admin_access_memberships.sql`,
asigna el primer administrador desde SQL Editor de Supabase usando el correo
exacto de una cuenta ya registrada:

```sql
insert into public.user_roles (user_id, role)
select id, 'admin'::public.user_role
from auth.users
where lower(email) = lower('admin@example.com')
on conflict (user_id, role) do nothing;
```

Reemplaza `admin@example.com` antes de ejecutar. Comprueba que se añadió una
sola fila y que el usuario puede volver a iniciar sesión. Solo un operador con
acceso confiable a la base debe ejecutar este SQL; nunca lo expongas como acción
del cliente ni incluyas una clave `service_role` en la aplicación.

Los planes de membresía existentes se mantienen. Si `subscription_plans` no
tiene planes activos, crea/configura los planes desde un entorno confiable
antes de habilitar solicitudes de membresía. Los pagos quedan pendientes de
verificación manual hasta integrar la pasarela.
