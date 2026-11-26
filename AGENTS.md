# AGENTS.md — academia_events

Instrucciones para agentes que trabajen en este repositorio. Leé este archivo
completo antes de tocar código. Lo que está acá **manda** sobre tus hábitos.

---

## 1. Reglas duras (no negociables)

1. **No ejecutes tests ni servidores sin permiso explícito del usuario.**
   Prohibido por defecto: `flutter test`, `flutter run`, `flutter drive`,
   `playwright test`, `npm test`, `nuxi prepare`, cualquier e2e y cualquier
   dev server. El permiso es **por ejecución**: si lo pidió una vez, no habilita
   las siguientes. Si una tarea parece requerir esa verificación, preguntá.
2. **Sí podés analizar estáticamente**: `dart analyze lib` o `flutter analyze`.
   Es la verificación por defecto del proyecto.
3. **No hagas DDL ni cambios destructivos en la base sin permiso**
   (`drop`, `alter`, `delete` masivo, `apply_migration`). Las consultas
   **de solo lectura** por MCP sí están permitidas para diagnosticar.
4. **No inventes funcionalidades de negocio.** El alcance lo define el usuario.
5. **No borres ni sobrescribas trabajo ajeno** (archivos modificados sin
   commitear). Investigá primero con `git status` / `git diff`.
6. **Toda tabla, columna, índice, trigger o policy nueva debe vivir en
   `supabase/migrations/`.** Nunca crees objetos solo en la base remota: eso
   genera *drift* y ya rompió consultas (ver §7.2).

---

## 2. Stack y estructura

| Capa | Tecnología |
|---|---|
| App | Flutter 3.47 / Dart 3.13 (`sdk: ^3.13.0`) |
| Estado | Riverpod 3 (`flutter_riverpod`, `riverpod_annotation`) |
| Navegación | go_router 17 |
| Backend | Supabase (Postgres + Auth + Storage + Edge Functions) |
| Pagos | PagosYa (checkout + webhooks + reconciliación) |
| Modelos | freezed / json_serializable / equatable |

```
lib/
  core/            config, constants (AppRoutes, AppSizes), router, theme, utils
  data/            models/ · repositories/ · services/   (acceso a Supabase)
  features/<x>/    views/ · widgets/                     (UI por feature)
  providers/       providers Riverpod (un archivo por dominio)
  shared/widgets/  componentes reutilizables (AppButton, AppErrorState, …)
supabase/
  migrations/      fuente de verdad del esquema (orden por fecha)
  functions/       pagosya-api, pagosya-webhook, pagosya-reconcile, send-push-notification
docs/              documentación funcional y de pruebas
```

**Patrón obligatorio:** `View` → `Provider` (Riverpod) → `Repository` →
`Service` (Supabase). La vista no habla con `supabase` directo; los `service`
no conocen widgets.

Features existentes: `academy, admin, auth, calendar, checkin, classes,
enrollment, events, notification, organization, profile, public, purchases,
tickets`.

---

## 3. Skills del proyecto

Viven en `.agents/skills/<nombre>/SKILL.md` y están registradas en
`skills-lock.json`.

**Regla:** antes de escribir código por una petición de diseño/UI, **leé el
`SKILL.md`** (y sus `references/*.md` relevantes). No implementes de memoria.

Disponibles:

| Skill | Usar cuando |
|---|---|
| `impeccable` | Diseñar, rediseñar, auditar o pulir UI. Modo **Operate** para paneles/tareas; corré `scripts/impeccable.cmd context --target <archivo>` y leé `reference/craft-floor.md` antes de editar |
| `mobile-app-ui-design` | Pantallas móviles: escala tipográfica, grid, tap targets, empty states |
| `flutter-expert` | Widgets, Riverpod, GoRouter, performance (`references/widget-patterns.md`) |
| `flutter-animations` | Animaciones implícitas/explícitas, Hero, curvas |
| `flutter-testing` | Tests de widgets/unitarios (solo si el usuario autoriza correrlos) |
| `accessibility` | Contraste, foco, etiquetas, tamaño de targets (WCAG 2.2) |
| `frontend-design` | Jerarquía visual, evitar estética genérica |
| `dart-best-practices` | Estilo y uso del lenguaje |
| `supabase` / `supabase-postgres-best-practices` | SQL, RLS, migraciones, RPC |
| `seo` | Solo si se toca web/landing |

**Instalar skills nuevas:** `npx skills add <owner/repo@skill> -y` (instala en
`.agents/skills`). Verificá instalaciones >1K y fuentes conocidas antes de
recomendar.

**Al terminar una tarea de UI, declarás qué skills aplicaste** y qué decisiones
salieron de cada una.

Context7: usalo para documentación de librerías/APIs (Flutter, Riverpod,
go_router, Supabase). No para refactors ni lógica de negocio.

---

## 4. Convenciones de código

- **Imports relativos** dentro de `lib/` (preferí el estilo del archivo que
  editás). `dart format` en los archivos que tocás.
- **`const`** en todo widget inmutable. Nada de construir widgets dentro de
  `build()` si son estáticos.
- **Riverpod 3**: `AsyncValue` expone `.value` (nullable). **No existe
  `valueOrNull`**. Usá `ref.watch(...select(...))` para acotar rebuilds.
- **Errores**: nunca tragues excepciones devolviendo `[]` en silencio. Si el
  contrato obliga a devolver una lista, al menos `debugPrint` con contexto
  (`// [SERVICE ... Error]`). Un `[]` mudo esconde bugs de producción.
- **Mensajes al usuario**: usá `friendlyError(e)` / `AppFeedback` y los estados
  compartidos (`AppErrorState`, `AppEmptyState`, `LoadingIndicator`).
- **Idioma**: UI, comentarios y commits en **español**. Copy de producto en
  voseo ("Creá una clase", "Elegí los días"), sentence case en títulos.
- **Terminología fija**: «inscrito/a» (nunca «inscripto/a»), «ritmo» para la
  categoría de baile, «pase» para packs de sesiones, «cupos» para capacidad.
- **Comentarios**: solo cuando explican *por qué*, no *qué*.
- **Encabezado de archivo**: `// lib/<ruta>.dart` cuando el archivo ya lo trae.

---

## 5. UI/UX (reglas del proyecto)

Aplican a toda pantalla nueva o modificada:

1. **Un solo `Scaffold`/`AppBar` por pantalla.** No envuelvas una vista que ya
   tiene `Scaffold` dentro de otro `Scaffold` en `app_router.dart` (causó doble
   header con dos flechas atrás).
2. **Solo tokens de tema.** Prohibido `Colors.white`, `Colors.black`,
   `Colors.grey` fijos: usá `context.textOnBg`, `context.textMuted`,
   `context.cardBg`, `context.divider`, `AppColors.*`. Un `Colors.white` sobre
   superficie clara deja texto invisible.
3. **Tipografía**: máximo 3–4 tamaños y 2–3 pesos por pantalla. Nada de texto
   por debajo de 9px salvo grillas densas.
4. **Espaciado** en múltiplos de 4/8; más aire arriba de un título que debajo.
5. **Targets táctiles ≥ 44×44** (nunca `IconButton` con `constraints: BoxConstraints()`).
6. **Accesibilidad**: íconos con `tooltip`, tarjetas con `Semantics(label: …)`,
   nunca comunicar estado solo con color (agregá ícono o texto).
7. **Estados obligatorios**: loading, error con reintento, vacío con guía + CTA.
   El vacío explica el siguiente paso y, si aplica, la diferencia
   borrador/publicado.
8. **Nombres de acción**: el botón dice lo que hace ("Nueva clase", no "+").
9. Evitá: doble header, cards anidadas, gradientes decorativos, sombras
   duras sin offset/blur, emojis como íconos.
10. **Grillas con alto fijo** (horarios, calendarios): nunca apiles N tarjetas
    en una franja; mostrá 2 como máximo + un botón "+N más" que abra la lista
    completa, y claveteá `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`
    para que la tipografía grande del sistema no desborde.

---

## 6. Navegación

- Rutas centralizadas en `AppRoutes` (`lib/core/constants/app_constants.dart`).
- Rutas nuevas: `GoRoute` con `parentNavigatorKey: rootNavigatorKey` para
  pantallas completas.
- La flecha atrás se resuelve en **un** lugar: `leading` explícito o el back
  automático del `AppBar`. Si la pantalla debe volver a un destino fijo, usá
  `context.go(...)` + `PopScope` como en `AcademyClassesView`.
- No dejes rutas muertas sin uso; si agregás una, enlazala desde la UI.

---

## 7. Supabase

### 7.1 Fuente de verdad
`supabase/migrations/*.sql` ordenadas por fecha. Antes de cambiar esquema:
listá migraciones, revisá la última y **creá una nueva** (no edites viejas ya
aplicadas). Verificá el estado real con `list_migrations` (MCP).

### 7.2 Drift: el bug que ya nos costó caro
La base tenía la tabla `dance_class_categories` **sin migración** y con 0 filas.
Eso hizo que el embed `dance_categories(name)` fuera ambiguo → PostgREST
devolvía `300 PGRST201` y todas las consultas de clases fallaban silenciosamente.

- **Regla:** cuando hay más de una relación entre dos tablas, siempre usá el
  hint explícito:
  `dance_categories!dance_classes_dance_category_id_fkey(name)`.
- **Regla:** probá toda consulta nueva contra la API real (REST con la anon key
  del `.env`, sin imprimir la clave) o contra Postgres, antes de dar por hecho
  que devuelve datos.

### 7.3 Columnas vigentes
`organizations` **no** tiene `city_id` (se usa `department_id`, `province_id`,
`municipality_id`, `location_name`, `address`, `latitude`, `longitude`).

### 7.4 Seguridad
- RLS está **desactivado** en `dance_classes`, `dance_class_schedules`,
  `dance_class_sessions` y `organizations`, y `anon` tiene `INSERT/UPDATE/DELETE`.
  Es una deuda de seguridad conocida: no la amplíes sin querer y no la cierres
  sin permiso (requiere políticas de lectura pública de `published`).
- Las funciones de negocio suelen ser `security definer` en `private.*` con
  wrapper público en `public.*`. No cambies los `grant`.
- Nunca hardcodees claves; salen de `.env` (`SUPABASE_URL`,
  `SUPABASE_PUBLIC_KEY`).

### 7.5 Modelo de negocio crítico

| Concepto | Regla |
|---|---|
| Membresía | `private.organization_has_active_membership` (cualquiera activa) y `..._monthly_membership` (exige `billing_interval = 'month'` y período vigente) |
| Crear clases/eventos | Trigger `guard_class_membership` / `guard_event_membership` → exige membresía activa |
| Publicar clase | Trigger `guard_class_publication_payment` → exige membresía **mensual** activa. La publicación está incluida en la suscripción: **no se cobra aparte** |
| Publicar evento | Trigger `guard_event_publication_payment` → exige membresía **mensual** + fila en `event_publication_payments` |
| Pago de publicación | Solo para **eventos**. El admin de plataforma puede generar el QR con monto libre; la **organización** (owner/admin/manager) también puede pagarlo desde el detalle del evento, usando `payment_platform_config.event_publication_price`. Al confirmarse el pago, `private.fulfill_publication` publica solo |
| Estado inicial | Clases y eventos nacen `draft`: no se ven en el público hasta publicarse |
| Sesiones | Se generan desde el detalle de la clase (`generateSessions`); sin sesiones no se puede comprar |
| Precios | `price` = por sesión, `price_monthly` = pase mensual |

---

## 8. Gotchas de API / lints (Flutter 3.47)

| Síntoma | Solución |
|---|---|
| `'activeColor' is deprecated` | `Switch`/`SwitchListTile` → `activeThumbColor` |
| `'groupValue'/'onChanged' deprecated` en `RadioListTile` | Envolvé con `RadioGroup<T>(groupValue:, onChanged:, child:)`; deshabilitá con `enabled:` |
| `unnecessary_underscores` | `(_, _, _)` en vez de `(_, __, ___)` |
| `use_null_aware_elements` | En mapas: `'k': ?maybeNull`; en listas: `?item` |
| `curly_braces_in_flow_control_structures` | Llaves en todo `if`/`for` multilínea |
| `depend_on_referenced_packages` | Importá `package:file_picker/file_picker.dart` (re-exporta la plataforma) |
| `valueOrNull` no existe | `AsyncValue.value` |
| `300 PGRST201` en PostgREST | Embed ambiguo → hint `tabla!fk_columna(...)` |

---

## 9. Flujo de trabajo esperado

1. Leer el código involucrado y `git status` antes de editar.
2. Si hay UI: cargar skills (§3) y el contexto de `impeccable`.
3. Implementar cambios mínimos y coherentes con el estilo del archivo.
4. `dart analyze lib` hasta **No issues found**; `dart format` de lo tocado.
5. Si tocaste SQL: dejarlo como migración nueva y avisar del drift.
6. Reportar: qué cambió, por qué, qué skills aplicaste y qué **no** pudiste
   verificar (porque correr la app requiere permiso).

---

## 10. Git

- Formato: `tipo(scope): descripción en español, minúscula, imperativo`.
  Tipos vistos: `feat`, `fix`, `refactor`, `chore`, `docs`.
  Ej.: `feat(pagosya): agregar modo sandbox con confirmacion simulada`.
- Un commit = un cambio lógico. No commitees sin que el usuario lo pida.
- No reescribas historia ni fuerces push.

---

## 11. Documentación existente

- `docs/pagosya-pruebas.md`, `docs/pagosya-saas-integracion.md`,
  `docs/push-notifications-setup.md`
- `supabase/PAGOSYA_SETUP.md`
- Si cambiás el flujo de pagos, membership o publicación, actualizá el doc
  correspondiente.
