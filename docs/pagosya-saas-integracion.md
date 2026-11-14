# PagosYa · Integración SaaS / Plataformas (documentación extraída)

> **Fuente:** <https://www.pagosya.com.bo/developers?producto=saas>
> **Extracción:** Playwright (Chromium) — 12/11/2026
> **Estado del producto:** SaaS / Plataformas · **Lanzamiento (beta)**.
> Si encuentras un error en la documentación, repórtalo a `soporte@pagosya.com.bo`.
>
> Este documento reproduce la documentación oficial de la integración **SaaS** de PagosYa
> (una sola integración para todos los comercios de tu plataforma). Las secciones
> interactivas de la web (etapas del alta y demo visual) se transcriben íntegras más abajo.

---

## Índice

1. [Resumen](#1-resumen)
2. [Arquitectura: una integración global](#2-arquitectura-una-integración-global)
3. [Cliente global (código base)](#3-cliente-global-código-base)
4. [Crear o retomar un comercio](#4-crear-o-retomar-un-comercio)
5. [Alta bancaria (sesiones temporales)](#5-alta-bancaria-sesiones-temporales)
6. [Cobros (ventas)](#6-cobros-ventas)
7. [Webhook global](#7-webhook-global)
8. [Comisiones y liquidación](#8-comisiones-y-liquidación)
9. [Capacidad y límites técnicos](#9-capacidad-y-límites-técnicos)
10. [Paso a producción / homologación](#10-paso-a-producción--homologación)
11. [Referencia de la API de plataforma](#11-referencia-de-la-api-de-plataforma)
12. [Demo visual de comisiones](#12-demo-visual-de-comisiones)
13. [Aplicación en esta app (Flutter)](#13-aplicación-en-esta-app-flutter)
14. [Enlaces y contacto](#14-enlaces-y-contacto)

---

## 1. Resumen

> **Una integración. Todos tus comercios.**

Integra PagosYa una vez en tu sistema. Cada comercio conecta su propio banco, recibe sus
ventas y liquida su comisión. Tu plataforma administra la cartera con una clave global.

**Propuesta de valor:**

- Backend de tu SaaS con **una clave global** (`spk_`).
- **Un receptor de webhook** para todos los comercios.
- **Un menú bancario reutilizable** dentro de tu producto.
- Cada comercio conserva su banco, historial y comisión; PagosYa resuelve las claves
  internas y tu owner **no las copia por cliente**.

**Lo que necesitas implementar:**

| Pieza | ¿Se implementa una vez? |
|---|---|
| Menú "Integración bancaria" | Sí, para todos los clientes |
| Endpoint backend con la clave global | Sí |
| Autorización del operador | Sí |
| Redirección segura a PagosYa | Sí |
| Webhook global | Sí |
| `external_id` / `affiliate_id` por comercio | No: uno por empresa |
| Datos, consentimiento, credenciales y validación bancaria | No: los completa cada titular |

---

## 2. Arquitectura: una integración global

**"Implementa el módulo una sola vez — Tu conexión global, una empresa por cobro."**

```
┌──────────────────────────────┐
│      Backend de tu SaaS      │
│  • Una clave global (spk_)   │
│  • Un receptor de webhook    │
│  • Un menú bancario          │
└──────────────┬───────────────┘
               │
   ┌───────────┴────────────┐
   │                        │
Andes Market           Café Norte
empresa-001            empresa-002
→ affiliate_id         → affiliate_id
   │                        │
Banco del comercio A   Banco del comercio B
```

> Cada empresa conserva su banco, historial y comisión. PagosYa resuelve las claves
> internas; tu owner no las copia por cliente. *(Nombres e identificadores ficticios.)*

**Responsabilidades por actor:**

- **Tu SaaS** — Un módulo bancario, un backend con la clave global y un webhook para toda
  la plataforma.
- **Cada comercio** — Su `external_id`, su `affiliate_id`, su banco y sus condiciones de
  comisión. **Sin otra cuenta o login de PagosYa.**
- **PagosYa** — Custodia las credenciales, valida el banco y resuelve la clave de
  producción del comercio internamente.

**Reglas de diseño:**

- Instala en tu producto el menú **Integración bancaria** y, si lo deseas, el de
  **Comisiones**. Habilítalos a las empresas que contraten cobros QR.
- Para incorporar otra empresa ejecutas **el mismo flujo con sus identificadores**; no
  repites el desarrollo, no copias contraseñas ni configuras una API key o webhook por
  cliente.
- **Antes de emitir sesiones o cobros, tu backend debe autenticar al operador y comprobar
  su acceso a la empresa.** Guarda la relación **empresa → `affiliate_id`** en tu base.
  `actor_ref` identifica al operador para auditoría; **no reemplaza esa autorización**.

---

## 3. Cliente global (código base)

> **Node.js** — *Una vez en el backend del SaaS. Nunca en React, móvil o el navegador.*

```js
// Una vez en el backend del SaaS. Nunca en React, móvil o el navegador.
// Antes de llamar, autentica al operador y autoriza su acceso al comercio.
async function pagosya(action, payload = {}) {
  const key = process.env.PAGOSYA_PLATFORM_KEY; // spk_ de tu plataforma
  if (!key) throw new Error('Falta PAGOSYA_PLATFORM_KEY');
  const response = await fetch('https://nbjwpakpimrqfocsxkda.supabase.co/functions/v1/saas-platform', {
    method: 'POST',
    headers: {
      Authorization: 'Bearer ' + key,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ action, payload })
  });
  const result = await response.json();
  if (!response.ok || result.error || result.success === false) {
    throw new Error(result.error || 'PAGOSYA_REQUEST_FAILED');
  }
  return result;
}
```

---

## 4. Crear o retomar un comercio

> **Node.js · por empresa**

```js
const commerce = await pagosya('merchant_create', {
  external_id: 'empresa-123', // ID estable de la empresa en tu SaaS
  display_name: 'Comercio Ejemplo', email: 'titular@ejemplo.com',
  branding_mode: 'powered_by_pagosya', // Embedded 1%; white_label = 2%
  payment_ui: 'both' // merchant | provider | both
});
// Guarda commerce.id como affiliate_id en ESA empresa, en tu servidor.
// Misma referencia y datos compatibles: retoma el comercio existente.
// No vuelvas a crearlo cada vez que el titular abra el menú.
```

**Reglas:**

- Un `external_id` ya usado con **datos incompatibles se rechaza**.
- Si el comercio ya tiene banco, plan o deuda en PagosYa, solicita una **vinculación
  asistida** para conservar su historial. **No crees otra identidad** para reiniciar sus
  obligaciones.
- `branding_mode`: `powered_by_pagosya` = Embedded (1 %) · `white_label` = White Label (2 %).
- `payment_ui`: `merchant` | `provider` | `both`.

---

## 5. Alta bancaria (sesiones temporales)

> **"Un menú permanente, sesiones temporales."**

La opción recomendada abre una **página segura alojada por PagosYa**. El titular sigue
trabajando desde el menú de tu SaaS y **no necesita registrarse ni iniciar sesión en
PagosYa**. El enlace temporal se genera al abrir el menú; los datos y el trámite permanecen
guardados.

### 5.1 Del alta al primer cobro (las 6 etapas)

| # | Etapa | Responsable | Estado de ejemplo | Acción / señal |
|---|---|---|---|---|
| 01 | **Afiliar** | Backend del SaaS | Comercio creado | `merchant_create` |
| 02 | **Solicitar** | Titular del comercio | Solicitud en seguimiento | `create_session · bank` |
| 03 | **Credenciales** | Banco → titular | Validación PagosYa pendiente | Menú *Integración bancaria* |
| 04 | **Conectar** | Equipo PagosYa | Integración verificada | `merchant_summary · bank.status` |
| 05 | **Cobrar** | Backend + comprador | Venta confirmada | `create_checkout → checkout.completed` |
| 06 | **Liquidar** | Comercio o proveedor | Comisión al día | `commission.invoice_created → commission.paid` |

**Descripción de cada etapa:**

1. **Afiliar** — Tu administrador acuerda 1 % o 2 %. Tu servidor crea el vínculo y guarda
   el `affiliate_id` junto a la empresa. Este paso **reserva un cupo del plan**; no exige
   otra cuenta al titular.
2. **Solicitar** — Desde *Integración bancaria* abres la página segura de PagosYa. El
   titular **acepta las condiciones, completa los datos BANECO y firma**. La solicitud
   aparece en el admin de PagosYa y el proveedor puede consultar su avance.
3. **Credenciales** — Cuando el banco entregue usuario, contraseña y cuenta, el titular
   vuelve al mismo menú. Tu backend **emite otra sesión** y retoma su registro. Guarda los
   datos directamente en PagosYa; **tu SaaS no recibe la contraseña**.
4. **Conectar** — PagosYa completa la clave AES y realiza la prueba bancaria. Solo después
   de la validación se informa **`connected`**. El proveedor ve el estado o recibe
   `bank.integration_updated`; no copia una API key por cliente.
5. **Cobrar** — El mismo módulo solicita el cobro para ese `affiliate_id`. El comprador paga
   al banco del comercio. Tu webhook verifica **firma, empresa, monto y referencia** antes
   de acreditar el pedido **una sola vez**.
6. **Liquidar** — La comisión se acumula por venta confirmada. Al cierre se emite una
   factura a PagosYa; el ciclo siguiente continúa. El comercio o proveedor puede abrir el
   pago, y el SaaS recibe la confirmación de liquidación.

**Lo que se implementa una vez vs. lo que cambia por comercio:**

- *Lo implementas una vez* — El menú, el endpoint de tu backend, la autorización del
  operador y la redirección segura son los mismos para todos tus clientes.
- *Cambia por cada comercio* — El vínculo de empresa, sus datos, el consentimiento, sus
  credenciales y su validación bancaria. Cada titular completa su propio trámite.

### 5.2 Abrir "Integración bancaria" · redirección recomendada

> **Node.js · sesión nueva en cada apertura**

```js
// El operador ya está autenticado y autorizado en tu SaaS.
// Obtén affiliateId de su empresa en tu base, no de un ID libre del navegador.
const session = await pagosya('create_session', {
  affiliate_id: affiliateId, component: 'bank',
  actor_ref: operatorId // Operador autenticado en tu SaaS
});
const bankUrl = 'https://www.pagosya.com.bo/plataformas/componente#'
  + session.token;
// Devuelve esta URL solo a ese operador y ábrela como redirección.
// Crea otra sesión en CADA apertura del menú "Integración bancaria".
// La URL vence en 30 minutos; el registro del comercio permanece.
```

**Sobre el estado del banco:**

- La **contraseña y la clave AES no se devuelven al proveedor**.
- `merchant_summary.bank` expone: estado de solicitud, `credentials_saved`, `aes_configured`
  y última prueba.
- **Solo `bank.status = connected`** indica banco activo, credenciales de producción y
  prueba aprobada. **Guardar credenciales o enviar la carta todavía no habilita cobros.**

### 5.3 Alternativa opcional: formulario en iframe

Solicita la autorización del **origen HTTPS exacto** y usa el endpoint de iframe. Los datos
bancarios viajan desde el componente a PagosYa; tu SaaS no los recibe.

> **Node.js / React**

```js
// Opcional: iframe con origen HTTPS exacto aprobado por PagosYa.
const session = await pagosya('create_session', {
  affiliate_id: affiliateId, component: 'bank',
  actor_ref: operatorId, origin: 'https://admin.tu-saas.com'
});
const src = 'https://www.pagosya.com.bo/api/saas-embed?session='
  + session.id + '#' + session.token;
// <iframe src={src} title="Integración bancaria"
//   referrerPolicy="no-referrer"
//   style={{width:'100%',height:850,border:0}} />
// No uses /plataformas/componente en un iframe.
// No envíes tokens ni credenciales bancarias mediante postMessage.
```

---

## 6. Cobros (ventas)

> **"Cobrar con el banco del comercio correcto."**

Usa la misma clave `spk_` en tu backend y el `affiliate_id` de la empresa autorizada.
PagosYa genera y vincula la **clave interna de producción del comercio**; el owner del SaaS
no tiene que copiarla ni pegarla en cada usuario. **El dinero de la venta llega al banco del
comercio.**

### 6.1 Tres pagos, destinos claros

El SaaS integra el servicio. La venta llega al banco del comercio y las obligaciones con
PagosYa se pagan por separado.

| Origen | Qué paga | Destino |
|---|---|---|
| Comprador | QR de la venta | **Banco del comercio** (ingreso de la venta) |
| Comercio | QR de comisión | PagosYa institucional (factura del ciclo cerrado) |
| Proveedor SaaS | QR de mensualidad | PagosYa institucional (licencia de la plataforma) |

### 6.2 Crear un cobro para un comercio

> **Node.js**

```js
const order = await pagosya('create_checkout', {
  affiliate_id: affiliateId, // Empresa autorizada por tu servidor
  checkout: {
    amount: 1, currency: 'BOB', order_id: 'pedido-123',
    expiration_minutes: 5,
    success_url: 'https://tu-saas.com/pago/confirmado',
    cancel_url: 'https://tu-saas.com/pago/cancelado',
    customer: { name: 'Cliente Ejemplo', email: 'cliente@ejemplo.com' }
  }
});
// PagosYa selecciona internamente el banco y la clave de ese comercio.
// Conserva order.checkout_id asociado a empresa + pedido.
// Muestra checkout_url o qr.data_url disponible según la modalidad.
// Ante un resultado incierto, conserva order_id y el cuerpo original;
// no crees otra referencia para repetir un cobro.
```

### 6.3 Consultar un pago desde el backend

> **Node.js**

```js
const payment = await pagosya('get_checkout_status', {
  affiliate_id: affiliateId,
  checkout_id: checkoutId // Guardado para ese comercio y pedido
});
// Solo status === 'completed' confirma una venta.
// Verifica referencia, monto y moneda contra tu pedido guardado.
// Una redirección de éxito o un QR mostrado no prueban el pago.
```

**Reglas de negocio:**

- Cada pedido debe guardar **comercio, monto, moneda y referencia**.
- Usa el **webhook** para procesar confirmaciones y consulta el estado para **reconciliar
  dudas**.
- Al reintentar, **conserva la referencia y los datos originales**.
- La modalidad y el banco determinan la respuesta disponible del checkout
  (`checkout_url` / `qr.data_url`).

---

## 7. Webhook global

> **"Un webhook global para tu plataforma."**

En *Integración API*, registra tu endpoint **HTTPS público en puerto 443** y guarda el
**secreto** en tu backend. Solicita primero la **autorización de su origen exacto**. Sin
redirecciones, parámetros, credenciales en la URL o IPs privadas; requiere **resolución IPv4
pública**.

### 7.1 Eventos

- `checkout.completed`
- `bank.integration_updated`
- `commission.invoice_created`
- `commission.paid`

### 7.2 Sobre (envelope)

El sobre contiene `id`, `event`, `created_at`, `affiliate_id`, `external_id` y `data`.
**No incluye contraseñas bancarias ni datos del comprador.** Un cambio bancario exige
revisar su estado: **no significa automáticamente conexión aprobada**.

### 7.3 Verificar la firma del webhook global

> **Node.js · HMAC SHA-256**

```js
import { createHmac, timingSafeEqual } from 'node:crypto';

function verifyPagosya(rawBody, signature, secret) {
  const match = /^t=(\d+),v1=([a-f0-9]{64})$/.exec(signature || '');
  if (!match || Math.abs(Date.now() / 1000 - Number(match[1])) > 300) {
    return false;
  }
  const expected = createHmac('sha256', secret)
    .update(match[1] + '.').update(rawBody).digest();
  return timingSafeEqual(expected, Buffer.from(match[2], 'hex'));
}
// rawBody: bytes originales del request, ANTES de parsear el JSON.
// X-PagosYa-Signature: t=UNIX_SECONDS,v1=HEX_HMAC_SHA256.
// Tras verificar, resuelve el comercio por affiliate_id + external_id
// y deduplica event.id con almacenamiento persistente.
// Guarda el trabajo de forma duradera antes de responder 2xx.
// No atribuyas un pago a un comercio basándote solo en order_id.
```

### 7.4 Cabeceras, reintentos y garantías

- Cabeceras: **`X-PagosYa-Event`**, **`X-PagosYa-Event-Id`** y **`X-PagosYa-Signature`**.
- El secreto se muestra **solo al crearlo o rotarlo**.
- Cada reintento conserva `event.id` y lleva un **timestamp firmado nuevo**.
- **No se garantiza el orden de entrega**: consulta el estado actual cuando sea necesario.
- **Hasta 8 intentos**: tras cada fallo, espera de **1 min, 5 min, 15 min, 1 h, 3 h, 6 h y
  12 h**.
- El panel muestra las **últimas 20 entregas** y permite **reintentar** después del último
  fallo.
- **Pausar** el webhook deja de crear eventos nuevos y conserva la cola existente; cambiar
  **URL o secreto** afecta los intentos posteriores.
- La recepción del **callback bancario**, la **confirmación financiera en PagosYa** y la
  **entrega a tu webhook** son etapas distintas. Revisa entregas fallidas y reconcilia por
  API.
- El contrato actual **no emite eventos específicos de vencimiento o bloqueo**: consulta
  `merchant_summary`.

---

## 8. Comisiones y liquidación

> **"Una barra clara y el pago a un clic."**

Puedes integrar el **componente financiero** de PagosYa o **diseñar tu pantalla con la API**.
En ambos casos, diferencia la **comisión del ciclo actual** de la **factura del ciclo ya
cerrado**. Explora el ejemplo para ver el plazo, el bloqueo y la confirmación del pago.

### 8.1 Quién presenta el pago (`payment_ui`)

| Valor | Significado |
|---|---|
| `payment_ui: merchant` | El titular consulta y abre el pago desde el módulo financiero que habilitas en su SaaS. |
| `payment_ui: provider` | Tu equipo consulta las facturas y genera un **enlace confidencial** para compartir por sus propios canales. |
| `payment_ui: both` | El proveedor y el titular disponen de la experiencia de liquidación. La factura y el estado son los mismos. |

> Estas opciones cambian **quién presenta el pago**; no transfieren la deuda al proveedor ni
> sustituyen la autorización del operador. El **QR institucional** liquida una factura de
> comisión. El **QR de una venta** cobra al comprador en el banco del comercio.

### 8.2 Cómo se cobra la comisión

- El **proveedor** paga su **mensualidad**.
- Cada **comercio** paga su **comisión** a PagosYa sobre **ventas confirmadas**:
  **Embedded 1 %** o **White Label 2 %**, según lo acordado por el administrador y aceptado
  por el titular.
- La **activación del afiliado está incluida en el plan SaaS**: no aplica la tarifa de
  **Bs 49,90** de la contratación individual.
- Por defecto, el **ciclo cierra cada 7 días** y la **factura vence 24 horas después**. Las
  condiciones aceptadas por cada comercio son las que rigen.
- Todo cierre con importe a liquidar **requiere pago, sin monto mínimo comercial**. El ciclo
  siguiente acumula mientras se liquida el anterior.
- **Ejemplo:** una venta confirmada de **BOB 100** acumula **BOB 1** con Embedded al 1 %, o
  **BOB 2** con White Label al 2 %. **Crear un QR pendiente todavía no genera esa
  comisión.** La deuda se liquida al cierre; el dinero de la venta **no se descuenta ni se
  retiene** para cobrarla.

### 8.3 Dos bloqueos independientes

| Causa | Efecto |
|---|---|
| **Mensualidad del SaaS vencida** | Se bloquean nuevos QR de **todos** sus comercios afiliados. |
| **Comisión del comercio vencida** | Se bloquean nuevos QR **solo de ese comercio**. Pagar una obligación no elimina la otra. |

- Los **pagos ya emitidos siguen confirmándose** y los medios para regularizar deudas
  permanecen disponibles.
- `payment_ui` define quién muestra la liquidación: `merchant`, `provider` o `both`.
- **El comercio sigue siendo el deudor.** El proveedor puede generar y compartir su enlace,
  **sin asumir la deuda**.

### 8.4 Pantalla financiera propia y pago de comisión

> **Node.js**

```js
const commerce = await pagosya('merchant_summary', {
  affiliate_id: affiliateId
});
// commerce.bank: conexión; commerce.summary: ciclo, facturas y bloqueo.
// Para tu propia pantalla financiera:
const qr = await pagosya('generate_commission_qr', {
  affiliate_id: affiliateId, invoice_id: invoiceId
});
const payment = await pagosya('commission_status', {
  affiliate_id: affiliateId, invoice_id: invoiceId
});
// Una factura liquidada tiene status === 'paid', no 'completed'.
// Consulta cada 2 segundos solo mientras muestres el QR.
// El servidor confirma pagos aunque la página esté cerrada.
```

### 8.5 Widget opcional o enlace para compartir una factura

> **Node.js**

```js
// Componentes: commission (barra/resumen) o settlement (liquidación).
const widget = await pagosya('create_session', {
  affiliate_id: affiliateId, component: 'commission',
  origin: 'https://admin.tu-saas.com' // Origen exacto aprobado
});
// URL de iframe: /api/saas-embed?session=ID#TOKEN (30 minutos).

// Enlace para pagar UNA factura: omite origin y fija invoice_id.
const invoice = await pagosya('create_session', {
  affiliate_id: affiliateId, component: 'settlement', invoice_id: invoiceId
});
const paymentUrl = 'https://www.pagosya.com.bo/plataformas/componente#'
  + invoice.token;
// Vence en 7 días. Compártelo por tu correo o WhatsApp.
// Es confidencial; no da acceso al banco ni a otra factura.
```

> Tu SaaS decide cómo avisar al comercio por sus canales. Los enlaces de factura son
> **confidenciales y temporales**; no los publiques. Las notificaciones a tu webhook **no
> sustituyen** los recordatorios de pago al titular.

---

## 9. Capacidad y límites técnicos

> **"Qué mide el plan y qué límites técnicos existen."**

El plan se dimensiona por **comercios afiliados reservados**, no por usuarios de tu SaaS ni
por número de desarrollos. Un comercio **ocupa cupo desde que se crea o invita**, incluso
antes de conectar su banco. **Pausarlo no libera ese cupo**; la reserva del período
permanece aunque se revoque. La capacidad se vuelve a calcular **al renovar**.

| Límite | Detalle |
|---|---|
| **Capacidad del proveedor** | Consulta `license.merchant_limit` y `capacity_used` en `overview`. La cartera se pagina de **100 en 100** con `offset`. No intercambies empresas para reutilizar cupos del mismo período. |
| **Ventas por comisión** | **Sin tope mensual** de volumen vendido del plan. No elimina los límites de peticiones, validaciones ni restricciones bancarias. |
| **API global** | Hasta **120 solicitudes por minuto por clave `spk_`**, compartidas entre los comercios que la utilizan. La ruta de cobros también respeta el límite de la clave interna del comercio (**60/min** por defecto). |
| **Sesiones bancarias** | Hasta **120 aperturas por hora por proveedor**; vigencia de **30 minutos**. Un enlace de liquidación fijado a una factura y sin `origin` dura hasta **7 días**. |

**Manejo de errores de límite:**

- Ante `RATE_LIMITED`, aplica **espera progresiva**; no emitas otra clave para eludir límites.
- Si alcanzas `MERCHANT_LIMIT_REACHED` o `PERIOD_CAPACITY_REACHED`, coordina el cambio de
  plan con soporte.
- Los cambios de plan vigentes son **asistidos**; no se promete prorrateo ni ampliación
  automática.

### Planes y contratación

Consulta los precios y cupos vigentes en **planes SaaS**. Elige una modalidad, crea tu
cuenta y registra tu plataforma. La activación requiere **aprobación administrativa y pago
mensual por QR**; la renovación necesita **pago confirmado**. **No hay prueba gratuita
automática.** Cualquier cortesía de piloto se acuerda y habilita individualmente con
PagosYa.

---

## 10. Paso a producción / homologación

> **"Del desarrollo al primer comercio en producción."**
> *El mismo sandbox de Checkout Web; el alta SaaS se homologa aparte.*

Solicita tu clave de prueba con el formulario de esta documentación. Se revisa por el mismo
flujo de **Checkout Web** y se envía por correo tras la aprobación.

- La clave **`sk_test_`** permite probar **ventas y QR ficticios** en
  `sandbox-create-checkout`.
- **No simula** afiliación SaaS, banco, comisiones, mensualidad o webhook global, ni
  reemplaza la clave de plataforma **`spk_`**.
- Las operaciones SaaS del piloto usan **infraestructura de producción**.

### Checklist de homologación

1. **Prepara tu sistema** — Implementa el módulo global y prueba tus pantallas con datos
   ficticios locales. Evita crear empresas o formularios ficticios en el banco de
   producción.
2. **Registra al proveedor** — Elige el plan SaaS en `/planes`, crea la cuenta del owner y
   registra tu plataforma en `/plataformas`. Espera la aprobación administrativa y confirma
   la mensualidad aplicable antes de pagar.
3. **Configura tu backend** — Genera la clave global en *Integración API* y guárdala como
   secreto del servidor. Autoriza los orígenes HTTPS de producción y registra el webhook y
   su secreto.
4. **Conecta un comercio real autorizado** — Crea el vínculo, abre la página bancaria,
   completa aceptación, formulario y firma. Cuando el banco entregue las credenciales, el
   titular vuelve a guardarlas; PagosYa completa la AES y aprueba la conexión.
5. **Homologa con un pago pequeño** — Verifica `bank.status=connected` y
   `checkout_allowed`. Crea una venta autorizada de **Bs 0,10** o **Bs 1** y confirma
   estado, firma, empresa, referencia, monto y moneda, **incluso con la página cerrada**.
6. **Verifica antes de ampliar** — Revisa **idempotencia**, **separación entre empresas**,
   **liquidación** y **entregas fallidas del webhook**. Prueba cierres y vencimientos solo
   sobre cuentas acordadas con PagosYa; después habilita gradualmente otros comercios.

> Para cambiar de tu desarrollo local a operación real, actualiza la **configuración del
> backend, dominios autorizados y receptor HTTPS**; no repitas la integración por comercio.
> Las altas, facturas y credenciales creadas en producción son **reales**. PagosYa valida
> cada nueva conexión bancaria antes de habilitarla.

---

## 11. Referencia de la API de plataforma

**Endpoint**

```
POST https://nbjwpakpimrqfocsxkda.supabase.co/functions/v1/saas-platform
```

**Autenticación**

```
Authorization: Bearer spk_…
Content-Type: application/json
```

**Cuerpo (envelope)**

```json
{ "action": "…", "payload": { … } }
```

> Todas las acciones se ejecutan **desde tu backend** con los permisos de la clave.

### 11.1 Acciones, permisos y campos

| Acción | Permiso | Payload |
|---|---|---|
| `merchant_create` | `invite` | `external_id`, `display_name`, `email`, `branding_mode`, `payment_ui` |
| `overview` | `read` | `offset` opcional; hasta 100 comercios por página |
| `merchant_summary` | `read` | `affiliate_id` |
| `affiliate_state` | `manage` | `affiliate_id`, `status` (`active`/`paused`), `payment_ui` opcional |
| `create_session` | `session` | `affiliate_id`, `component`, `origin` opcional; **`actor_ref` obligatorio para `bank`** |
| `create_checkout` | `sales` | `affiliate_id`, `checkout` |
| `get_checkout_status` | `read` | `affiliate_id`, `checkout_id` |
| `generate_commission_qr` | `settle` | `affiliate_id`, `invoice_id` |
| `commission_status` | `settle` | `affiliate_id`, `invoice_id` |
| `webhook_get` | `manage` | `{}` |
| `webhook_set` | `manage` | `url`, `enabled`, `rotate` opcional |
| `webhook_retry` | `manage` | `event_id`; después de 8 intentos fallidos |

### 11.2 Códigos de error documentados

| Código | Significado / acción |
|---|---|
| `BANK_INTEGRATION_REQUIRED` | Aún no hay banco listo. |
| `SAAS_PROVIDER_SUBSCRIPTION_REQUIRED` | Mensualidad no vigente. |
| `COMMISSION_PAYMENT_OVERDUE` | Deuda individual vencida. |
| `SESSION_UNAVAILABLE` | Emite otra sesión después de autorizar al operador. |
| `EXISTING_MERCHANT_CONTACT_ADMIN` | Requiere vinculación asistida. |
| `RATE_LIMITED` | Aplica espera progresiva. |
| `MERCHANT_LIMIT_REACHED` | Límite de comercios del plan; coordina con soporte. |
| `PERIOD_CAPACITY_REACHED` | Capacidad del período agotada; coordina con soporte. |

> Un error temporal **no es prueba de pago ni de deuda**; consulta el estado antes de actuar.

### 11.3 Seguridad de las sesiones

- Las sesiones **`sps_`** son **credenciales temporales**: no las guardes en analítica, logs
  o enlaces públicos.
- El SaaS **no necesita ni recibe** claves internas de otros comercios.
- Para revisar tu cartera, entra en **Mi plataforma**.

### 11.4 Formulario de acceso al piloto

**Solicita acceso al piloto SaaS** — Completa tu solicitud. Se revisa la plataforma y, tras
aprobar el acceso al sandbox de Checkout Web, se envía la clave **`sk_test_`** al correo
indicado. El alta SaaS, los bancos y el webhook global se coordinan durante el piloto.

- La solicitud usa el mismo proceso de revisión de **Developers**.
- **Enviarla no activa una licencia SaaS ni genera una clave de producción.**

Campos del formulario: Nombre completo*, Correo profesional*, WhatsApp*, Nombre del SaaS o
plataforma*, Sitio web o nombre de la aplicación (opcional), Cuéntanos sobre tu integración*,
Aceptación de la Política de Privacidad*.

---

## 12. Demo visual de comisiones

> *"Ejemplo visual inspirado en el dashboard. Cambia de estado para explorar el flujo."*
> **Demo · datos ficticios.** Esta demostración es local: sus botones no generan QR, no
> consultan al banco y no modifican cuentas. Los importes y el contador son ilustrativos.

**Contexto del ejemplo:** *Andes POS · Comercio de ejemplo* — Banco conectado —
Comisión API — **Embedded · 1 %** — **BOB 25,00 del ciclo actual** — día 4 de 7 (cierra en
3 días).

> La barra muestra el **avance del ciclo**, no un límite de ventas.

| Estado | Factura del ciclo anterior | Acceso a la API |
|---|---|---|
| **1. Acumulando** | BOB 0,00 — *Todavía no hay factura cerrada* | API disponible · puede generar nuevos QR |
| **2. Ciclo cerrado** | BOB 84,00 — *Paga en 12:34:56* (contador ilustrativo) | API disponible · puede generar nuevos QR |
| **3. Comisión vencida** | BOB 84,00 — *Plazo vencido · requiere liquidación* | **Nuevos QR bloqueados** (comisión del comercio vencida) |
| **4. Liquidada** | BOB 0,00 — *Factura pagada* | API disponible · puede generar nuevos QR |

**Reglas que ilustra la demo:**

- Se puede simular también la **mensualidad del SaaS vencida**: aunque liquides la comisión,
  **todos los afiliados siguen bloqueados** hasta regularizar la mensualidad.
- **Durante las 24 horas:** la factura cerrada y el ciclo nuevo conviven. Puedes seguir
  cobrando mientras no exista otra causa de bloqueo.
- **Después de pagar:** la confirmación del servidor actualiza la factura y el acceso. Los
  pagos se confirman **aunque la ventana esté cerrada**.

---

## 13. Aplicación en esta app (Flutter)

Notas de encaje derivadas de las reglas de la documentación (no forman parte del sitio):

- La **clave `spk_` nunca debe viajar al cliente**. En una app Flutter (móvil/web) no se
  puede llamar directamente a `saas-platform`: hace falta un **backend propio** (o una Edge
  Function) que guarde el secreto y aplique la autorización del operador.
- `merchant_create`, `create_session`, `create_checkout`, `get_checkout_status`,
  `webhook_*`, `generate_commission_qr` y `commission_status` se ejecutan **solo en el
  servidor**.
- El cliente Flutter puede:
  - abrir la **redirección** `https://www.pagosya.com.bo/plataformas/componente#<token>` en
    el navegador del sistema o en un WebView, o
  - mostrar el **iframe** de `/api/saas-embed` en web (con `origin` exacto aprobado) y
    `referrerPolicy="no-referrer"`.
- Para el cobro, el cliente muestra `checkout_url` o `qr.data_url`; la app **no** debe
  acreditar el pedido hasta que el backend confirme `status === 'completed'` o llegue el
  webhook **con firma válida**.
- Guarda en tu base la relación **empresa → `affiliate_id`** y el `actor_ref` del operador;
  no aceptes `affiliate_id` enviados libremente por el cliente.
- Los enlaces de liquidación (`settlement`) son **confidenciales**: no los publiques ni los
  registres en logs/analítica.

---

## 14. Enlaces y contacto

- Documentación SaaS: <https://www.pagosya.com.bo/developers?producto=saas>
- Checkout Web (otro producto): <https://www.pagosya.com.bo/developers>
- Planes SaaS: <https://www.pagosya.com.bo/planes#saas>
- Plataformas: <https://www.pagosya.com.bo/plataformas>
- Privacidad: <https://www.pagosya.com.bo/privacidad>
- Soporte: `soporte@pagosya.com.bo`

---

## 15. Implementación en este repositorio

La integración ya está aplicada al proyecto `academy` (`jhrtpaswcotnwiikdtop`):
migración, RPCs, RLS, tres Edge Functions desplegadas y el flujo de compra de la
app adaptado.

| Archivo | Rol |
|---|---|
| `supabase/migrations/20261112120000_pagosya_saas_integration.sql` | Tablas, columnas, RPCs y revokes |
| `supabase/functions/_shared/pagosya.ts` | Firma HMAC, cliente PagosYa, CORS |
| `supabase/functions/pagosya-api/index.ts` | `create_checkout`, `refresh_checkout`, `merchant_create`, `create_bank_session`, `merchant_summary` |
| `supabase/functions/pagosya-webhook/index.ts` | Receptor público (401 sin firma válida) |
| `supabase/functions/pagosya-reconcile/index.ts` | Reconciliación + liberación de stock para `pg_cron` |
| `lib/data/services/pagosya_service.dart` | Cliente Flutter de la Edge Function |
| `lib/features/tickets/views/pagosya_checkout_screen.dart` | QR / enlace + polling de confirmación |

**Cambio de seguridad importante:** `public.confirm_event_order_payment` y
`public.purchase_class_pass` ya no son ejecutables por `anon` ni `authenticated`.
Solo `service_role` puede confirmar pagos y activar pases/membresías, y lo hace
únicamente desde `pagosya_apply_checkout_completed` (webhook o reconciliador).

**Cobertura:** tickets de eventos, pases de clase (`class_enrollments`) y
membresías (`subscriptions`) usan el mismo checkout. Las compras abandonadas se
cancelan y liberan stock con `pagosya_expire_stale_payments(30)`.

Pasos manuales pendientes (detalle en `supabase/PAGOSYA_SETUP.md`): cargar
secretos, registrar el webhook en PagosYa y dar de alta cada organización
(`merchant_create` + conexión bancaria).

---

*Documento generado a partir del contenido público de la página de desarrolladores de
PagosYa (producto SaaS) el 12/11/2026. La documentación está marcada como beta y puede
cambiar; verifica siempre contra la web oficial antes de implementar en producción.*
