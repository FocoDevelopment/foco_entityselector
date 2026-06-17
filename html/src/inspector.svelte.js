// inspector.svelte.js — reactive state + NUI bridge (Svelte 5 runes)

function resourceName() {
  return typeof window.GetParentResourceName === 'function'
    ? window.GetParentResourceName()
    : 'lime_entityselector';
}

export function postNui(endpoint, data = {}) {
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  })
    .then((r) => r.json())
    .catch(() => null);
}

// FiveM's NUI browser blocks navigator.clipboard; textarea trick instead.
export function copyText(text) {
  const ta = document.createElement('textarea');
  ta.value = text ?? '';
  ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0;';
  document.body.appendChild(ta);
  ta.focus();
  ta.select();
  let ok = false;
  try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
  document.body.removeChild(ta);
  return ok;
}

class Store {
  open = $state(false);
  entity = $state(null);
  frozen = $state(false);
  toast = $state(null);

  #toastTimer = null;

  showOpen(data) {
    this.entity = data;
    this.frozen = !!(data && data.frozen);
    this.open = true;
  }

  update(data) {
    this.entity = this.entity ? { ...this.entity, ...data } : data;
  }

  close() {
    this.open = false;
  }

  setFrozen(state) {
    this.frozen = !!state;
  }

  flashToast(payload) {
    this.toast = payload;
    if (this.#toastTimer) clearTimeout(this.#toastTimer);
    this.#toastTimer = setTimeout(() => (this.toast = null), 2600);
  }

  // -- Actions ----------------------------------------------
  closePanel() {
    this.open = false;
    postNui('close');
  }
  teleport() { postNui('teleport'); }
  toggleFreeze() { postNui('freeze'); }
  deleteEntity() { postNui('delete'); }
}

export const store = new Store();

// -- Message bridge -----------------------------------------
export function initBridge() {
  function onMessage(e) {
    const d = e.data || {};
    switch (d.type) {
      case 'open':        store.showOpen(d.data); break;
      case 'update':      if (store.open) store.update(d.data); break;
      case 'close':       store.close(); break;
      case 'freezeState': store.setFrozen(d.data && d.data.frozen); break;
      case 'toast':       store.flashToast(d.data); break;
    }
  }
  function onKey(e) {
    if (e.key === 'Escape' && store.open) store.closePanel();
  }
  window.addEventListener('message', onMessage);
  document.addEventListener('keydown', onKey);
  return () => {
    window.removeEventListener('message', onMessage);
    document.removeEventListener('keydown', onKey);
  };
}
