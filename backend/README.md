# FleteGG API

## Qué es

Backend HTTP (Node.js + Express) para FleteGG, el marketplace de fletes tipo
"Uber de camiones" en Santiago, Chile. Expone endpoints para:

- El formulario de afiliación de conductores de la landing.
- El webhook de confirmación de pago de Flow.cl.
- Un panel de administración simple (aprobar conductores, ver viajes y métricas).

La app Flutter vive en el resto de este repo; este backend solo se encarga de
las piezas que no pueden correr en el cliente (leads públicos con rate-limit,
verificación de pagos con Flow, y operaciones admin con Firebase Admin SDK).

## Requisitos

- Node.js 18 o superior (probado con Node 24).
- Un service account de Firebase con acceso a Firestore (proyecto de la app FleteGG).
- Credenciales de Flow.cl (API Key + Secret), sandbox o producción.

## Instalación

```bash
cd backend
npm ci
cp .env.example .env
# completar .env con las credenciales reales (Firebase, Flow, ADMIN_TOKEN, CORS_ORIGINS)
```

## Correr local

```bash
npm run dev
# o: npm start
```

Probar que levantó:

```bash
curl http://127.0.0.1:5912/api/health
# {"ok":true,"service":"fletegg-api","version":"1.0.0","uptimeSec":1,"ts":"..."}
```

Si faltan las variables de Firebase (`FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`,
`FIREBASE_PRIVATE_KEY`), el servidor no levanta: imprime un error claro y sale
con código distinto de 0.

## Producción con PM2 (VM eggclaw-auth)

```bash
cd backend
npm ci --omit=dev
pm2 start ecosystem.config.js
pm2 save
pm2 logs fletegg-api
```

El `.env` se carga desde `server.js` vía `dotenv`; PM2 solo necesita saber el
`PORT` (ya seteado en `ecosystem.config.js`). El proceso escucha en
`127.0.0.1:5912` — nunca expuesto directo a internet.

## nginx

`deploy/nginx-fletegg.conf` (fuera de `backend/`) hace el proxy:

```
https://eggclaw.cl/fletegg/api/  ->  http://127.0.0.1:5912/api/
```

Es decir, las rutas que ve la app Flutter (`/fletegg/api/...`) llegan al
backend ya sin ese prefijo (`/api/...`).

## Endpoints

| Método | Path                                     | Auth           | Descripción                                   |
|--------|-------------------------------------------|----------------|------------------------------------------------|
| GET    | `/api/health`                             | ninguna        | Healthcheck                                   |
| POST   | `/api/conductores/afiliar`                | pública (rate-limited) | Lead de afiliación desde la landing  |
| POST   | `/api/flow/webhook`                       | Flow (vía getStatus firmado) | Confirmación de pago Flow.cl |
| POST   | `/api/admin/conductores/:id/aprobar`      | `Bearer ADMIN_TOKEN` | Aprueba un conductor/afiliación         |
| GET    | `/api/admin/conductores`                  | `Bearer ADMIN_TOKEN` | Lista conductores y afiliaciones        |
| GET    | `/api/admin/viajes`                       | `Bearer ADMIN_TOKEN` | Lista viajes con filtros                |
| GET    | `/api/admin/metrics`                      | `Bearer ADMIN_TOKEN` | Métricas operativas del día             |

### Afiliar conductor

```bash
curl -X POST https://eggclaw.cl/fletegg/api/conductores/afiliar \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Juan Pérez",
    "telefono": "+56 9 1234 5678",
    "tipoVehiculo": "furgon",
    "patente": "AB1234",
    "zona": "centro",
    "disponibilidad": "flexible"
  }'
```

### Aprobar conductor (admin)

```bash
curl -X POST https://eggclaw.cl/fletegg/api/admin/conductores/<id>/aprobar \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### Métricas (admin)

```bash
curl https://eggclaw.cl/fletegg/api/admin/metrics \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## Webhook de Flow

El `urlConfirmation` configurado en Flow.cl debe ser:

```
https://eggclaw.cl/fletegg/api/flow/webhook
```

Flow hace un POST `application/x-www-form-urlencoded` con un solo campo
`token`. **No hay firma que verificar en ese POST** (Flow no firma las
notificaciones entrantes). La verificación real consiste en llamar a la API
de Flow (`GET /payment/getStatus`) con una request firmada por nosotros
(`FLOW_SECRET`, HMAC-SHA256) usando ese `token`, y confiar solo en esa
respuesta para actualizar el estado del viaje en Firestore.

- Producción: `FLOW_BASE_URL=https://www.flow.cl/api`
- Sandbox: `FLOW_BASE_URL=https://sandbox.flow.cl/api`

El viaje se busca en `viajes/{commerceOrder}` (donde `commerceOrder` es el
`viajeId` que le pasamos a Flow al crear el pago).

## Seguridad

- `ADMIN_TOKEN` protege todas las rutas `/api/admin/*`. Si no está seteado,
  esas rutas responden `503` en vez de quedar abiertas.
- **Nunca** commitear `.env` (ya está en `.gitignore`). Usar `.env.example`
  como plantilla y guardar los valores reales solo en la VM / gestor de
  secretos.
- El token de admin se compara con `crypto.timingSafeEqual` para evitar
  timing attacks.

## Índices de Firestore

Las consultas de `/api/admin/viajes` (estado + rango de `createdAt`) y de
`/api/admin/metrics` (`tipo` + `aprobado` + `enLinea`) combinan varios campos y
Firestore pide **índices compuestos**. La primera vez que fallen, el log de
`pm2 logs fletegg-api` muestra el error `FAILED_PRECONDITION` con un link
directo a la consola para crear el índice con un clic. Crearlos antes de abrir
el panel admin.
