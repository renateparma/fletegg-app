/* FleteGG landing — vanilla JS, sin dependencias. */

// nginx hace proxy de /fletegg/api/ al API Node (puerto 5912 en eggclaw-auth).
// Para desarrollo local, define window.FLETEGG_API_BASE antes de cargar este
// script (ej: 'http://localhost:5912') o cambia esta constante.
const API_BASE = (typeof window !== 'undefined' && window.FLETEGG_API_BASE) || '/fletegg/api';

const MSG = {
  nombre: 'Ingresa tu nombre (mínimo 2 letras)',
  telefono: 'Ingresa un celular chileno válido (+56 9 …)',
  select: 'Elige una opción',
  patente: 'Patente inválida. Ej: ABCD12',
  email: 'Ingresa un correo válido',
  rate: 'Demasiados intentos, prueba de nuevo en unos minutos.',
  generic: 'No pudimos enviar tu solicitud. Escríbenos a hola@eggclaw.cl o intenta de nuevo.'
};

document.documentElement.classList.add('js');

/* ---------- Utilidades ---------- */

function $(sel, ctx) { return (ctx || document).querySelector(sel); }

function normalizarTelefono(raw) {
  let t = String(raw || '').replace(/[\s\-().]/g, '');
  if (/^9\d{8}$/.test(t)) t = '+56' + t;
  else if (/^569\d{8}$/.test(t)) t = '+' + t;
  return t;
}

function normalizarPatente(raw) {
  return String(raw || '').toUpperCase().replace(/[\s\-]/g, '');
}

function setFieldError(form, name, message) {
  const input = form.elements[name];
  const err = $('#err-' + name, form);
  if (!input) return;
  if (message) {
    input.setAttribute('aria-invalid', 'true');
    if (err) err.textContent = message;
  } else {
    input.removeAttribute('aria-invalid');
    if (err) err.textContent = '';
  }
}

function clearErrors(form, names) {
  names.forEach(function (n) { setFieldError(form, n, ''); });
}

function showAlert(box, message) {
  if (!box) return;
  box.textContent = message;
  box.hidden = false;
}

function hideAlert(box) {
  if (!box) return;
  box.textContent = '';
  box.hidden = true;
}

/* ---------- Header: borde al hacer scroll ---------- */

(function headerScroll() {
  const header = $('.site-header');
  if (!header) return;
  const update = function () {
    header.classList.toggle('is-scrolled', window.scrollY > 8);
  };
  update();
  window.addEventListener('scroll', update, { passive: true });
})();

/* ---------- Año dinámico ---------- */

(function year() {
  const el = $('#year');
  if (el) el.textContent = String(new Date().getFullYear());
})();

/* ---------- Aparición de secciones al scroll ---------- */

(function reveal() {
  const items = document.querySelectorAll('.reveal');
  if (!items.length) return;
  if (!('IntersectionObserver' in window)) {
    items.forEach(function (el) { el.classList.add('in-view'); });
    return;
  }
  const io = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add('in-view');
        io.unobserve(entry.target);
      }
    });
  }, { rootMargin: '0px 0px -10% 0px', threshold: 0.08 });
  items.forEach(function (el) { io.observe(el); });
})();

/* ---------- Formulario de afiliación de conductores ---------- */

(function afiliar() {
  const form = $('#form-afiliar');
  if (!form) return;

  const alertBox = $('#afiliar-alert');
  const submitBtn = $('#afiliar-submit');
  const FIELDS = ['nombre', 'telefono', 'tipoVehiculo', 'patente', 'zona', 'disponibilidad'];
  const submitLabel = submitBtn ? submitBtn.textContent : 'Quiero afiliarme';

  // Limpia el error del campo apenas el usuario lo corrige.
  FIELDS.forEach(function (name) {
    const input = form.elements[name];
    if (!input) return;
    input.addEventListener('input', function () { setFieldError(form, name, ''); });
    input.addEventListener('change', function () { setFieldError(form, name, ''); });
  });

  function validar() {
    const errors = {};
    const nombre = form.elements.nombre.value.trim();
    const telefono = normalizarTelefono(form.elements.telefono.value);
    const tipoVehiculo = form.elements.tipoVehiculo.value;
    const patente = normalizarPatente(form.elements.patente.value);
    const zona = form.elements.zona.value;
    const disponibilidad = form.elements.disponibilidad.value;

    if (nombre.length < 2) errors.nombre = MSG.nombre;
    if (!/^\+569\d{8}$/.test(telefono)) errors.telefono = MSG.telefono;
    if (!tipoVehiculo) errors.tipoVehiculo = MSG.select;
    if (patente && !/^[A-Z0-9]{6,8}$/.test(patente)) errors.patente = MSG.patente;
    if (!zona) errors.zona = MSG.select;
    if (!disponibilidad) errors.disponibilidad = MSG.select;

    return {
      errors: errors,
      payload: {
        nombre: nombre,
        telefono: telefono,
        tipoVehiculo: tipoVehiculo,
        patente: patente,
        zona: zona,
        disponibilidad: disponibilidad,
        website: form.elements.website ? form.elements.website.value : ''
      }
    };
  }

  function setLoading(on) {
    if (!submitBtn) return;
    submitBtn.disabled = on;
    submitBtn.textContent = on ? 'Enviando…' : submitLabel;
    submitBtn.setAttribute('aria-busy', on ? 'true' : 'false');
  }

  function renderSuccess(nombre, telefono, duplicado) {
    const card = document.createElement('div');
    card.className = 'card success-card';
    card.setAttribute('role', 'status');
    card.tabIndex = -1;

    const icon = document.createElement('div');
    icon.className = 'success-icon';
    icon.innerHTML = '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M20 6 9 17l-5-5"/></svg>';

    const title = document.createElement('h3');
    title.textContent = '¡Listo, ' + nombre + '!';

    const text = document.createElement('p');
    text.textContent = duplicado
      ? 'Ya tenías una solicitud con ese número, te contactamos pronto.'
      : 'Te escribimos por WhatsApp al ' + telefono + ' para activar tu cuenta.';

    card.appendChild(icon);
    card.appendChild(title);
    card.appendChild(text);
    form.replaceWith(card);
    card.focus();
  }

  form.addEventListener('submit', async function (ev) {
    ev.preventDefault();
    hideAlert(alertBox);
    clearErrors(form, FIELDS);

    const result = validar();
    const invalid = FIELDS.filter(function (n) { return result.errors[n]; });
    if (invalid.length) {
      invalid.forEach(function (n) { setFieldError(form, n, result.errors[n]); });
      const first = form.elements[invalid[0]];
      if (first) first.focus();
      return;
    }

    // Refleja la normalización en pantalla (ej. "9 1234 5678" -> "+56912345678").
    form.elements.telefono.value = result.payload.telefono;
    form.elements.patente.value = result.payload.patente;

    setLoading(true);
    const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
    const timer = controller ? setTimeout(function () { controller.abort(); }, 12000) : null;

    try {
      const res = await fetch(API_BASE + '/conductores/afiliar', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify(result.payload),
        signal: controller ? controller.signal : undefined
      });

      let data = {};
      try { data = await res.json(); } catch (_) { data = {}; }

      if (res.status === 201 || (res.status === 200 && data && data.ok === true)) {
        renderSuccess(result.payload.nombre, result.payload.telefono, data && data.duplicado === true);
        return;
      }

      if (res.status === 400) {
        const campo = data && data.campo;
        const msg = (data && data.error) || 'Revisa este campo';
        if (campo && FIELDS.indexOf(campo) !== -1) {
          setFieldError(form, campo, msg);
          form.elements[campo].focus();
        } else {
          showAlert(alertBox, (data && data.error) || MSG.generic);
        }
        return;
      }

      if (res.status === 429) {
        showAlert(alertBox, MSG.rate);
        return;
      }

      showAlert(alertBox, MSG.generic);
    } catch (_) {
      // Error de red, timeout o CORS. Nunca se registra el payload en consola.
      showAlert(alertBox, MSG.generic);
    } finally {
      if (timer) clearTimeout(timer);
      if (form.isConnected) setLoading(false);
    }
  });
})();

/* ---------- Lista de espera de clientes ---------- */

(function waitlist() {
  const form = $('#form-waitlist');
  if (!form) return;

  const okMsg = $('#waitlist-ok');
  const KEY = 'fletegg_waitlist';

  function guardar(email) {
    try {
      const raw = window.localStorage.getItem(KEY);
      const list = raw ? JSON.parse(raw) : [];
      const arr = Array.isArray(list) ? list : [];
      if (arr.indexOf(email) === -1) arr.push(email);
      window.localStorage.setItem(KEY, JSON.stringify(arr));
    } catch (_) {
      // localStorage no disponible (modo privado, etc.): no bloquea el mensaje de éxito.
    }
  }

  form.elements.email.addEventListener('input', function () { setFieldError(form, 'email', ''); });

  form.addEventListener('submit', function (ev) {
    ev.preventDefault();
    const email = form.elements.email.value.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
      setFieldError(form, 'email', MSG.email);
      form.elements.email.focus();
      return;
    }
    setFieldError(form, 'email', '');
    guardar(email);
    // TODO: endpoint /api/clientes/waitlist
    form.hidden = true;
    if (okMsg) {
      okMsg.hidden = false;
      okMsg.tabIndex = -1;
      okMsg.focus();
    }
  });
})();
