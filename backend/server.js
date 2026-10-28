'use strict';

require('dotenv').config();

const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const pkg = require('./package.json');

// ---------------------------------------------------------------------------
// Firebase Admin init — falla rápido si faltan credenciales.
// ---------------------------------------------------------------------------
const { FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY } = process.env;

if (!FIREBASE_PROJECT_ID || !FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
  console.error(
    '[fatal] Faltan variables de entorno de Firebase. ' +
      'Se requieren FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL y FIREBASE_PRIVATE_KEY. ' +
      'Copia backend/.env.example a backend/.env y complétalas con los datos del service account.'
  );
  process.exit(1);
}

try {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: FIREBASE_PROJECT_ID,
      clientEmail: FIREBASE_CLIENT_EMAIL,
      privateKey: FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    }),
  });
} catch (err) {
  console.error('[fatal] No se pudo inicializar Firebase Admin:', err.message);
  process.exit(1);
}

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Constantes / enums (deben coincidir con la app Flutter)
// ---------------------------------------------------------------------------
const TIPO_VEHICULO = ['camion34', 'furgon', 'camioneta', 'varios'];
const ZONAS = ['centro', 'oriente', 'sur', 'norte', 'poniente', 'todaRm'];
const DISPONIBILIDADES = ['fullTime', 'finesSemana', 'eventos', 'flexible'];
const ESTADOS_VIAJE = ['pendiente', 'asignado', 'enOrigen', 'enCamino', 'completado', 'cancelado'];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Normaliza un teléfono chileno a formato +569XXXXXXXX. Devuelve null si no se puede. */
function normalizePhone(raw) {
  if (typeof raw !== 'string') return null;
  let s = raw.replace(/[\s-]/g, '');
  if (!s) return null;
  if (s.startsWith('+')) {
    // ya trae el +, no tocar
  } else if (s.startsWith('56')) {
    s = `+${s}`;
  } else if (s.startsWith('9')) {
    s = `+56${s}`;
  } else {
    s = `+${s}`;
  }
  return s;
}

/** Convierte recursivamente cualquier Timestamp de Firestore a string ISO. */
function serializeValue(v) {
  if (v === null || v === undefined) return v;
  if (typeof v.toDate === 'function') {
    return v.toDate().toISOString();
  }
  if (Array.isArray(v)) return v.map(serializeValue);
  if (typeof v === 'object') {
    const out = {};
    for (const k of Object.keys(v)) out[k] = serializeValue(v[k]);
    return out;
  }
  return v;
}

/** Serializa un DocumentSnapshot de Firestore a un objeto plano con id. */
function serializeDoc(doc) {
  return { id: doc.id, ...serializeValue(doc.data()) };
}

/** Fecha 'YYYY-MM-DD' siguiente a la dada (aritmética calendárica en UTC, sin horas). */
function nextDateStr(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + 1);
  return dt.toISOString().slice(0, 10);
}

/** Offset horario ('+HH:MM' o '-HH:MM') vigente en America/Santiago para una fecha dada. */
function santiagoOffsetForDate(dateStr) {
  const ref = new Date(`${dateStr}T12:00:00Z`);
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Santiago',
    timeZoneName: 'longOffset',
  }).formatToParts(ref);
  const tzPart = parts.find((p) => p.type === 'timeZoneName');
  const match = tzPart && tzPart.value.match(/GMT([+-]\d{2}:\d{2})/);
  return match ? match[1] : '-04:00';
}

/** Instante correspondiente a las 00:00:00 hora de Santiago para 'YYYY-MM-DD'. */
function santiagoDayStart(dateStr) {
  const offset = santiagoOffsetForDate(dateStr);
  return new Date(`${dateStr}T00:00:00${offset}`);
}

/** Fecha de hoy ('YYYY-MM-DD') en hora de Santiago. */
function santiagoTodayStr() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Santiago' }).format(new Date());
}

/** Ejecuta una query de conteo agregado (.count()) y devuelve el número. */
async function countQuery(query) {
  const snap = await query.count().get();
  return snap.data().count;
}

/**
 * Firma de Flow: todos los params excepto 's', ordenados alfabéticamente por key,
 * concatenados como key+value (sin separadores), HMAC-SHA256 con FLOW_SECRET, hex.
 */
function flowSign(params) {
  const secret = process.env.FLOW_SECRET || '';
  const keys = Object.keys(params)
    .filter((k) => k !== 's')
    .sort();
  const toSign = keys.map((k) => `${k}${params[k]}`).join('');
  return crypto.createHmac('sha256', secret).update(toSign).digest('hex');
}

async function flowGetStatus(token) {
  const apiKey = process.env.FLOW_API_KEY;
  const baseUrl = process.env.FLOW_BASE_URL || 'https://www.flow.cl/api';
  const s = flowSign({ apiKey, token });
  const url = `${baseUrl}/payment/getStatus?apiKey=${encodeURIComponent(apiKey)}&token=${encodeURIComponent(
    token
  )}&s=${s}`;
  // Timeout: si Flow no responde, devolvemos 502 y Flow reintenta.
  const resp = await fetch(url, { signal: AbortSignal.timeout(10_000) });
  if (!resp.ok) {
    throw new Error(`Flow getStatus HTTP ${resp.status}`);
  }
  return resp.json();
}

// ---------------------------------------------------------------------------
// Rate limit en memoria (solo para /api/conductores/afiliar)
// ---------------------------------------------------------------------------
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;
const rateLimitMap = new Map();

// Poda periódica para que el mapa no crezca sin límite con IPs distintas.
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of rateLimitMap) {
    if (now - entry.windowStart > RATE_LIMIT_WINDOW_MS) rateLimitMap.delete(key);
  }
}, RATE_LIMIT_WINDOW_MS).unref();

function checkRateLimit(ip) {
  const key = ip || 'unknown';
  const now = Date.now();
  const entry = rateLimitMap.get(key);
  if (!entry || now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
    rateLimitMap.set(key, { count: 1, windowStart: now });
    return true;
  }
  if (entry.count >= RATE_LIMIT_MAX) return false;
  entry.count += 1;
  return true;
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------
const app = express();
app.set('trust proxy', 'loopback'); // nginx corre en la misma VM

const allowedOrigins = (process.env.CORS_ORIGINS || 'https://eggclaw.cl')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

app.use(
  cors({
    origin(origin, callback) {
      // Sin Origin: curl, server-to-server, webhook de Flow -> permitir.
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new Error('No permitido por CORS'));
    },
  })
);

app.use(express.json({ limit: '50kb' }));
app.use(express.urlencoded({ extended: false, limit: '50kb' }));

// Log de una línea por request.
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const ms = Date.now() - start;
    console.log(`${req.method} ${req.originalUrl} ${res.statusCode} ${ms}ms`);
  });
  next();
});

// ---------------------------------------------------------------------------
// Middleware admin
// ---------------------------------------------------------------------------
function requireAdmin(req, res, next) {
  const adminToken = process.env.ADMIN_TOKEN;
  if (!adminToken) {
    return res.status(503).json({ ok: false, error: 'Admin no configurado' });
  }
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer (.+)$/);
  if (!match) {
    return res.status(401).json({ ok: false, error: 'No autorizado' });
  }
  const provided = Buffer.from(match[1]);
  const expected = Buffer.from(adminToken);
  if (provided.length !== expected.length || !crypto.timingSafeEqual(provided, expected)) {
    return res.status(401).json({ ok: false, error: 'No autorizado' });
  }
  next();
}

// ---------------------------------------------------------------------------
// Rutas
// ---------------------------------------------------------------------------
const START_TIME = Date.now();

app.get('/api/health', (req, res) => {
  res.json({
    ok: true,
    service: 'fletegg-api',
    version: pkg.version,
    uptimeSec: Math.round((Date.now() - START_TIME) / 1000),
    ts: new Date().toISOString(),
  });
});

app.post('/api/conductores/afiliar', async (req, res, next) => {
  try {
    const ip = req.ip;
    if (!checkRateLimit(ip)) {
      return res.status(429).json({ ok: false, error: 'Demasiadas solicitudes, intenta más tarde' });
    }

    const body = req.body || {};

    // Honeypot: si viene lleno, respondemos OK sin hacer nada (parece un bot).
    if (typeof body.website === 'string' && body.website.trim() !== '') {
      return res.status(200).json({ ok: true });
    }

    const nombre = typeof body.nombre === 'string' ? body.nombre.trim() : '';
    if (nombre.length < 2 || nombre.length > 80) {
      return res.status(400).json({ ok: false, error: 'Nombre inválido', campo: 'nombre' });
    }

    const telefono = normalizePhone(body.telefono);
    if (!telefono || !/^\+569\d{8}$/.test(telefono)) {
      return res.status(400).json({ ok: false, error: 'Teléfono inválido', campo: 'telefono' });
    }

    const tipoVehiculo = body.tipoVehiculo;
    if (!TIPO_VEHICULO.includes(tipoVehiculo)) {
      return res.status(400).json({ ok: false, error: 'Tipo de vehículo inválido', campo: 'tipoVehiculo' });
    }

    const zona = body.zona;
    if (!ZONAS.includes(zona)) {
      return res.status(400).json({ ok: false, error: 'Zona inválida', campo: 'zona' });
    }

    const disponibilidad = body.disponibilidad;
    if (!DISPONIBILIDADES.includes(disponibilidad)) {
      return res.status(400).json({ ok: false, error: 'Disponibilidad inválida', campo: 'disponibilidad' });
    }

    let patente = null;
    if (body.patente !== undefined && body.patente !== null && String(body.patente).trim() !== '') {
      patente = String(body.patente).toUpperCase().replace(/[\s-]/g, '');
      if (!/^[A-Z0-9]{6,8}$/.test(patente)) {
        return res.status(400).json({ ok: false, error: 'Patente inválida', campo: 'patente' });
      }
    }

    const existing = await db.collection('afiliaciones').where('telefono', '==', telefono).limit(1).get();
    if (!existing.empty) {
      return res.status(200).json({ ok: true, duplicado: true });
    }

    const docRef = await db.collection('afiliaciones').add({
      nombre,
      telefono,
      tipoVehiculo,
      patente,
      zona,
      disponibilidad,
      origen: 'landing',
      aprobado: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      userAgent: req.headers['user-agent'] || null,
      ip,
    });

    return res.status(201).json({ ok: true, id: docRef.id });
  } catch (err) {
    return next(err);
  }
});

// `/api/flow/confirm` es alias: es la URL que menciona lib/services/pago_service.dart.
app.post(['/api/flow/webhook', '/api/flow/confirm'], async (req, res, next) => {
  try {
    if (!process.env.FLOW_API_KEY || !process.env.FLOW_SECRET) {
      return res.status(503).json({ ok: false, error: 'Flow no configurado' });
    }

    const token = req.body && req.body.token;
    if (!token) {
      return res.status(400).json({ ok: false, error: 'token requerido' });
    }

    let status;
    try {
      status = await flowGetStatus(token);
    } catch (err) {
      console.error('[flow] falló getStatus:', err.message);
      return res.status(502).json({ ok: false, error: 'Error consultando Flow' });
    }

    const { commerceOrder, flowOrder, amount, status: flowStatus, requestDate, payer } = status || {};
    const PAGO_ESTADO_MAP = { 1: 'pendiente', 2: 'pagado', 3: 'rechazado', 4: 'anulado' };
    const pagoEstado = PAGO_ESTADO_MAP[flowStatus] || 'desconocido';

    if (!commerceOrder) {
      console.error('[flow] respuesta de getStatus sin commerceOrder:', JSON.stringify(status));
      return res.status(200).json({ ok: true });
    }

    try {
      const viajeRef = db.collection('viajes').doc(commerceOrder);
      const viajeSnap = await viajeRef.get();
      if (!viajeSnap.exists) {
        console.log(`[flow] viaje ${commerceOrder} no existe, se ignora notificación`);
        return res.status(200).json({ ok: true });
      }

      const viajeData = viajeSnap.data();
      const update = {
        pagoEstado,
        pagoFlowOrder: flowOrder,
        pagoMonto: Number(amount),
        pagoToken: token,
        pagoRaw: { status: flowStatus, requestDate, payer },
      };

      const yaPagado = viajeData.pagoEstado === 'pagado';
      if (!(yaPagado && pagoEstado === 'pagado')) {
        update.pagoAt = admin.firestore.FieldValue.serverTimestamp();
      }

      await viajeRef.update(update);
      return res.status(200).json({ ok: true });
    } catch (err) {
      console.error('[flow] error actualizando viaje:', err.message);
      return res.status(502).json({ ok: false, error: 'Error actualizando viaje' });
    }
  } catch (err) {
    return next(err);
  }
});

app.post('/api/admin/conductores/:id/aprobar', requireAdmin, async (req, res, next) => {
  try {
    const { id } = req.params;
    const fieldsAprobado = { aprobado: true, aprobadoAt: admin.firestore.FieldValue.serverTimestamp() };

    const usuarioRef = db.collection('usuarios').doc(id);
    const usuarioSnap = await usuarioRef.get();
    if (usuarioSnap.exists && usuarioSnap.data().tipo === 'conductor') {
      await usuarioRef.update(fieldsAprobado);
      return res.json({ ok: true, coleccion: 'usuarios', id });
    }

    const afiliacionRef = db.collection('afiliaciones').doc(id);
    const afiliacionSnap = await afiliacionRef.get();
    if (afiliacionSnap.exists) {
      await afiliacionRef.update(fieldsAprobado);
      return res.json({ ok: true, coleccion: 'afiliaciones', id });
    }

    return res.status(404).json({ ok: false, error: 'No encontrado' });
  } catch (err) {
    return next(err);
  }
});

app.get('/api/admin/conductores', requireAdmin, async (req, res, next) => {
  try {
    const { aprobado } = req.query;

    let conductoresQuery = db.collection('usuarios').where('tipo', '==', 'conductor');
    let afiliacionesQuery = db.collection('afiliaciones').orderBy('createdAt', 'desc');

    if (aprobado === 'true' || aprobado === 'false') {
      const boolVal = aprobado === 'true';
      conductoresQuery = conductoresQuery.where('aprobado', '==', boolVal);
      afiliacionesQuery = afiliacionesQuery.where('aprobado', '==', boolVal);
    }

    const [conductoresSnap, afiliacionesSnap] = await Promise.all([
      conductoresQuery.get(),
      afiliacionesQuery.get(),
    ]);

    return res.json({
      ok: true,
      conductores: conductoresSnap.docs.map(serializeDoc),
      afiliaciones: afiliacionesSnap.docs.map(serializeDoc),
    });
  } catch (err) {
    return next(err);
  }
});

app.get('/api/admin/viajes', requireAdmin, async (req, res, next) => {
  try {
    const { estado, desde, hasta } = req.query;

    let limit = parseInt(req.query.limit, 10);
    if (!Number.isFinite(limit) || limit <= 0) limit = 100;
    if (limit > 500) limit = 500;

    if (estado !== undefined && !ESTADOS_VIAJE.includes(estado)) {
      return res.status(400).json({ ok: false, error: 'estado inválido' });
    }

    const FECHA_RE = /^\d{4}-\d{2}-\d{2}$/;
    if (desde !== undefined && !FECHA_RE.test(desde)) {
      return res.status(400).json({ ok: false, error: 'desde inválido, usar YYYY-MM-DD' });
    }
    if (hasta !== undefined && !FECHA_RE.test(hasta)) {
      return res.status(400).json({ ok: false, error: 'hasta inválido, usar YYYY-MM-DD' });
    }

    let query = db.collection('viajes');
    if (estado) query = query.where('estado', '==', estado);
    if (desde) query = query.where('createdAt', '>=', santiagoDayStart(desde));
    if (hasta) query = query.where('createdAt', '<', santiagoDayStart(nextDateStr(hasta)));
    query = query.orderBy('createdAt', 'desc').limit(limit);

    const snap = await query.get();
    const viajes = snap.docs.map(serializeDoc);
    return res.json({ ok: true, count: viajes.length, viajes });
  } catch (err) {
    return next(err);
  }
});

app.get('/api/admin/metrics', requireAdmin, async (req, res, next) => {
  try {
    const hoyStr = santiagoTodayStr();
    const mananaStr = nextDateStr(hoyStr);
    const inicioHoy = santiagoDayStart(hoyStr);
    const inicioManana = santiagoDayStart(mananaStr);

    const [
      viajesHoy,
      viajesHoyCompletados,
      conductoresActivos,
      conductoresEnLinea,
      afiliacionesPendientes,
      completadosSnap,
    ] = await Promise.all([
      countQuery(db.collection('viajes').where('createdAt', '>=', inicioHoy).where('createdAt', '<', inicioManana)),
      countQuery(
        db
          .collection('viajes')
          .where('createdAt', '>=', inicioHoy)
          .where('createdAt', '<', inicioManana)
          .where('estado', '==', 'completado')
      ),
      countQuery(db.collection('usuarios').where('tipo', '==', 'conductor').where('aprobado', '==', true)),
      countQuery(
        db
          .collection('usuarios')
          .where('tipo', '==', 'conductor')
          .where('aprobado', '==', true)
          .where('enLinea', '==', true)
      ),
      countQuery(db.collection('afiliaciones').where('aprobado', '==', false)),
      db.collection('viajes').where('estado', '==', 'completado').get(),
    ]);

    let ingresoTotal = 0;
    let volumenTotal = 0;
    completadosSnap.forEach((doc) => {
      const d = doc.data();
      ingresoTotal += Number(d.comision) || 0;
      volumenTotal += Number(d.precioTotal) || 0;
    });

    return res.json({
      ok: true,
      viajesHoy,
      viajesHoyCompletados,
      conductoresActivos,
      conductoresEnLinea,
      afiliacionesPendientes,
      ingresoTotal,
      volumenTotal,
      ts: new Date().toISOString(),
    });
  } catch (err) {
    return next(err);
  }
});

// 404 para rutas no encontradas.
app.use((req, res) => {
  res.status(404).json({ ok: false, error: 'No encontrado' });
});

// Error handler central: nunca filtrar stack traces.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[error]', err && err.message);
  if (err && err.message === 'No permitido por CORS') {
    return res.status(403).json({ ok: false, error: 'Origen no permitido' });
  }
  return res.status(err && err.status ? err.status : 500).json({ ok: false, error: 'Error interno' });
});

// ---------------------------------------------------------------------------
// Arranque
// ---------------------------------------------------------------------------
const PORT = process.env.PORT || 5912;
app.listen(PORT, '127.0.0.1', () => {
  console.log(`fletegg-api escuchando en http://127.0.0.1:${PORT}`);
});

module.exports.flowSign = flowSign;
module.exports.serializeDoc = serializeDoc;
module.exports.normalizePhone = normalizePhone;
module.exports.santiagoDayStart = santiagoDayStart;
