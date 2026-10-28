# FleteGG landing

Landing pública de FleteGG (EggClaw Solutions): hero, cómo funciona, precios de referencia, afiliación de conductores y lista de espera de clientes. HTML/CSS/JS estático, sin frameworks, sin CDN, sin build.

**Deploy:** copiar la carpeta completa a `/var/www/eggclaw/fletegg/` en la VM `eggclaw-auth`; nginx la sirve en `https://eggclaw.cl/fletegg/` y hace proxy de `/fletegg/api/` al API Node (puerto 5912, ver `../backend/`).

**URL del API:** `const API_BASE` al inicio de `app.js` (default `/fletegg/api`). Para desarrollo local, definir `window.FLETEGG_API_BASE = 'http://localhost:5912'` antes de cargar el script.

**Pendiente:** la lista de espera de clientes guarda el correo en `localStorage` (`fletegg_waitlist`); falta el endpoint `/api/clientes/waitlist` (marcado con `TODO` en `app.js`).
