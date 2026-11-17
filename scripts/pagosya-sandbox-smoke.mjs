#!/usr/bin/env node
// Pruebas de humo del sandbox de PagosYa (Checkout Web).
//
// Uso:
//   node scripts/pagosya-sandbox-smoke.mjs
//   node scripts/pagosya-sandbox-smoke.mjs --out docs/pagosya-pruebas/mi-carpeta
//
// Lee la clave desde `supabase/functions/.env` (PAGOSYA_SANDBOX_KEY) o desde
// las variables de entorno. Nunca imprime la clave completa.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const DEFAULT_URL =
  "https://nbjwpakpimrqfocsxkda.supabase.co/functions/v1/sandbox-create-checkout";

function loadEnv(path) {
  const out = {};
  if (!existsSync(path)) return out;
  for (const line of readFileSync(path, "utf8").split(/\r?\n/)) {
    const m = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/.exec(line);
    if (!m) continue;
    out[m[1]] = m[2].replace(/^["']|["']$/g, "").trim();
  }
  return out;
}

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const fileEnv = loadEnv(join(ROOT, "supabase", "functions", ".env"));
const KEY = process.env.PAGOSYA_SANDBOX_KEY ?? fileEnv.PAGOSYA_SANDBOX_KEY ?? "";
const URL_ = process.env.PAGOSYA_SANDBOX_URL ?? fileEnv.PAGOSYA_SANDBOX_URL ?? DEFAULT_URL;
const MODE = process.env.PAGOSYA_MODE ?? fileEnv.PAGOSYA_MODE ?? "(sin definir)";

const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
const OUT = resolve(ROOT, arg("--out") ?? join("docs", "pagosya-pruebas", stamp));
mkdirSync(OUT, { recursive: true });

const results = [];
let seq = 0;

function redact(text) {
  return String(text).split(KEY).join("sk_test_***");
}

async function post(body, { key = KEY, headers = {} } = {}) {
  const res = await fetch(URL_, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
      ...headers,
    },
    body: JSON.stringify(body),
  });
  const raw = await res.text();
  let json = null;
  try {
    json = JSON.parse(raw);
  } catch {
    /* respuesta no JSON */
  }
  return {
    status: res.status,
    headers: Object.fromEntries(res.headers.entries()),
    json,
    raw: redact(raw),
  };
}

function checkoutBody(overrides = {}) {
  seq += 1;
  return {
    amount: 1,
    currency: "BOB",
    order_id: `smoke-${stamp}-${seq}`.replace(/[^A-Za-z0-9._-]/g, "-"),
    success_url: "https://example.com/pago/ok",
    cancel_url: "https://example.com/pago/cancel",
    ...overrides,
  };
}

function qrDataUrl(json) {
  return json?.qr?.data_url ?? json?.qr_image ?? json?.qr_data_url ?? null;
}

function saveQr(json, filename) {
  const dataUrl = qrDataUrl(json);
  if (!dataUrl || !dataUrl.startsWith("data:image")) return null;
  const comma = dataUrl.indexOf(",");
  if (comma < 0) return null;
  const file = join(OUT, filename);
  writeFileSync(file, Buffer.from(dataUrl.slice(comma + 1), "base64"));
  return file;
}

async function run(id, name, expected, fn) {
  const started = Date.now();
  let record;
  try {
    record = await fn();
    record = { id, name, expected, ok: record.ok, ...record };
  } catch (err) {
    record = {
      id,
      name,
      expected,
      ok: false,
      error: redact(err?.message ?? err),
    };
  }
  record.ms = Date.now() - started;
  results.push(record);
  const icon = record.ok ? "PASS" : "FAIL";
  console.log(`[${icon}] ${id} · ${name} · ${record.ms}ms`);
  if (record.detail) console.log(`       ${record.detail}`);
  return record;
}

console.log("PagosYa · pruebas de sandbox");
console.log(`  endpoint : ${URL_}`);
console.log(`  modo     : ${MODE}`);
console.log(
  `  clave    : ${KEY ? `${KEY.slice(0, 8)}… (${KEY.length} chars)` : "NO CONFIGURADA"}`,
);
console.log(`  salida   : ${OUT}\n`);

if (!KEY) {
  console.error("Falta PAGOSYA_SANDBOX_KEY en supabase/functions/.env o en el entorno.");
  process.exit(2);
}
if (!KEY.startsWith("sk_test_")) {
  console.error("PAGOSYA_SANDBOX_KEY no empieza con sk_test_: no es una clave de sandbox.");
  process.exit(2);
}
if (MODE !== "sandbox") {
  console.warn(
    `Aviso: PAGOSYA_MODE="${MODE}". La app no usará el sandbox hasta que valga "sandbox".`,
  );
}

let happy = null;

await run(
  "T1",
  "Checkout válido devuelve QR ficticio",
  "201 + environment=sandbox, livemode=false, status=pending, QR data URL",
  async () => {
    const r = await post(checkoutBody());
    happy = r;
    const j = r.json ?? {};
    const qr = qrDataUrl(j);
    const file = saveQr(j, "qr-embedded.png");
    const ok =
      r.status === 201 &&
      j.livemode === false &&
      j.environment === "sandbox" &&
      j.status === "pending" &&
      typeof qr === "string" &&
      qr.startsWith("data:image");
    return {
      ok,
      status: r.status,
      detail: [
        `checkout_id=${j.checkout_id ?? j.id ?? "-"}`,
        `expires_at=${j.expires_at ?? "-"}`,
        file ? `QR guardado en ${file}` : "sin QR",
      ].join(" · "),
      response: j,
    };
  },
);

await run(
  "T2",
  "White-label devuelve QR sin sello",
  "201 + QR data URL",
  async () => {
    const r = await post(checkoutBody({ branding_mode: "white_label" }));
    const j = r.json ?? {};
    const file = saveQr(j, "qr-white-label.png");
    return {
      ok: r.status === 201 && !!qrDataUrl(j),
      status: r.status,
      detail: file ? `QR guardado en ${file} (revisar visualmente que no tenga sello)` : "sin QR",
      response: j,
    };
  },
);

await run(
  "T3",
  "order_id duplicado se rechaza",
  "409 DUPLICATE_ORDER_ID",
  async () => {
    const body = checkoutBody();
    const first = await post(body);
    const second = await post(body);
    const code = second.json?.error ?? second.json?.code;
    return {
      ok: first.status === 201 && second.status === 409 && code === "DUPLICATE_ORDER_ID",
      status: second.status,
      detail: `primera=${first.status} · segunda=${second.status} · error=${code ?? "-"}`,
      response: second.json,
    };
  },
);

await run(
  "T4",
  "Clave inválida se rechaza",
  "401",
  async () => {
    const r = await post(checkoutBody(), { key: "sk_test_clave_invalida_del_smoke_test" });
    return {
      ok: r.status === 401,
      status: r.status,
      detail: `error=${r.json?.error ?? "-"}`,
      response: r.json,
    };
  },
);

await run(
  "T5",
  "Falta success_url",
  "400",
  async () => {
    const body = checkoutBody();
    delete body.success_url;
    const r = await post(body);
    return {
      ok: r.status === 400,
      status: r.status,
      detail: `error=${r.json?.error ?? "-"}`,
      response: r.json,
    };
  },
);

await run(
  "T6",
  "Monto inválido (0) se rechaza",
  "400",
  async () => {
    const r = await post(checkoutBody({ amount: 0 }));
    return {
      ok: r.status === 400,
      status: r.status,
      detail: `error=${r.json?.error ?? "-"}`,
      response: r.json,
    };
  },
);

await run(
  "T7",
  "Metadatos propios se aceptan",
  "201",
  async () => {
    const r = await post(
      checkoutBody({ metadata: { pedido_interno: "SMOKE-1", canal: "script" } }),
    );
    return {
      ok: r.status === 201,
      status: r.status,
      detail: `error=${r.json?.error ?? "-"}`,
      response: r.json,
    };
  },
);

await run(
  "T8",
  "Expiración dentro del rango sandbox",
  "201 con expiration_minutes=60",
  async () => {
    const r = await post(checkoutBody({ expiration_minutes: 60 }));
    return {
      ok: r.status === 201,
      status: r.status,
      detail: `expires_at=${r.json?.expires_at ?? "-"}`,
      response: r.json,
    };
  },
);

await run(
  "T9",
  "Headers de rate limit presentes",
  "X-RateLimit-Limit / Remaining",
  async () => {
    const h = happy?.headers ?? {};
    const limit = h["x-ratelimit-limit"];
    const remaining = h["x-ratelimit-remaining"];
    return {
      ok: Boolean(limit),
      status: happy?.status ?? 0,
      detail: `limit=${limit ?? "-"} · remaining=${remaining ?? "-"}`,
      optional: !limit,
    };
  },
);

// ---------------------------------------------------------------- evidencia
const passed = results.filter((r) => r.ok).length;
const requiredFails = results.filter((r) => !r.ok && !r.optional);

const summary = [
  "# PagosYa · pruebas de sandbox",
  "",
  `- Fecha: ${new Date().toISOString()}`,
  `- Endpoint: ${URL_}`,
  `- Modo configurado: ${MODE}`,
  `- Clave: ${KEY.slice(0, 8)}… (${KEY.length} caracteres)`,
  `- Resultado: **${passed}/${results.length} pruebas OK**`,
  "",
  "| ID | Prueba | Esperado | Estado | HTTP | Detalle |",
  "|---|---|---|---|---|---|",
  ...results.map(
    (r) =>
      `| ${r.id} | ${r.name} | ${r.expected} | ${r.ok ? "PASS" : "FAIL"} | ${r.status ?? "-"} | ${(r.detail ?? r.error ?? "").replace(/\|/g, "\\|")} |`,
  ),
  "",
  "> El sandbox no confirma pagos ni envía webhooks: estas pruebas validan",
  "> autenticación, validación de datos, respuestas y generación del QR ficticio.",
  "",
].join("\n");

writeFileSync(join(OUT, "report.md"), summary);
writeFileSync(
  join(OUT, "report.json"),
  JSON.stringify(
    {
      ran_at: new Date().toISOString(),
      endpoint: URL_,
      mode: MODE,
      key_prefix: `${KEY.slice(0, 8)}…`,
      results,
    },
    null,
    2,
  ),
);

console.log(`\n${passed}/${results.length} pruebas OK`);
console.log(`Evidencia: ${join(OUT, "report.md")}`);

if (requiredFails.length > 0) {
  console.error(`\nFallaron ${requiredFails.length} prueba(s) obligatoria(s).`);
  process.exit(1);
}
