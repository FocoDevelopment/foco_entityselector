// windowManager.svelte.js — draggable/resizable window state (runes)

const MIN_W = 300;
const MIN_H = 360;
const MARGIN = 8; // keep this much on-screen

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
}

class WindowManager {
  // Position + size (px). x/y are top-left.
  x = $state(0);
  y = $state(0);
  w = $state(340);
  h = $state(0); // 0 = auto height until first resize

  dragging = $state(false);
  resizing = $state(false);

  #mode = null;       // 'drag' | resize edge string e.g. 'e','se'
  #start = null;      // pointer + box snapshot at gesture start
  #placed = false;    // has the window been positioned yet this session

  // Place near the left-center the first time the panel opens, but keep
  // whatever the user dragged to on subsequent opens.
  ensurePlaced() {
    if (this.#placed) return;
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    this.x = Math.round(vw * 0.05);
    this.y = Math.round(vh * 0.5 - 320);
    if (this.y < MARGIN) this.y = MARGIN;
    this.#placed = true;
  }

  // Called by the title bar.
  startDrag(e) {
    this.#beginGesture('drag', e);
  }

  // Called by a resize handle; dir is one of n,s,e,w,ne,nw,se,sw.
  startResize(e, dir) {
    // Lock current rendered height into h so resize math has a base.
    if (this.h === 0) {
      const el = document.getElementById('lime-window');
      if (el) this.h = el.offsetHeight;
    }
    this.#beginGesture(dir, e);
  }

  #beginGesture(mode, e) {
    e.preventDefault();
    this.#mode = mode;
    this.#start = {
      px: e.clientX,
      py: e.clientY,
      x: this.x,
      y: this.y,
      w: this.w,
      h: this.h || (document.getElementById('lime-window')?.offsetHeight ?? MIN_H),
    };
    if (mode === 'drag') this.dragging = true;
    else this.resizing = true;

    window.addEventListener('pointermove', this.#onMove, { passive: false });
    window.addEventListener('pointerup', this.#onUp, { passive: true });
  }

  #onMove = (e) => {
    if (!this.#start) return;
    e.preventDefault?.();

    const dx = e.clientX - this.#start.px;
    const dy = e.clientY - this.#start.py;
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const s = this.#start;

    if (this.#mode === 'drag') {
      this.x = clamp(s.x + dx, MARGIN - s.w + 60, vw - 60);
      this.y = clamp(s.y + dy, MARGIN, vh - 40);
      return;
    }

    let nx = s.x, ny = s.y, nw = s.w, nh = s.h;
    const m = this.#mode;

    if (m.includes('e')) nw = clamp(s.w + dx, MIN_W, vw - s.x - MARGIN);
    if (m.includes('s')) nh = clamp(s.h + dy, MIN_H, vh - s.y - MARGIN);
    if (m.includes('w')) {
      const right = s.x + s.w;
      nw = clamp(s.w - dx, MIN_W, right - MARGIN);
      nx = right - nw;
    }
    if (m.includes('n')) {
      const bottom = s.y + s.h;
      nh = clamp(s.h - dy, MIN_H, bottom - MARGIN);
      ny = bottom - nh;
    }

    this.x = nx; this.y = ny; this.w = nw; this.h = nh;
  };

  #onUp = () => {
    this.dragging = false;
    this.resizing = false;
    this.#mode = null;
    this.#start = null;
    window.removeEventListener('pointermove', this.#onMove);
    window.removeEventListener('pointerup', this.#onUp);
  };

  get style() {
    const h = this.h ? `height:${this.h}px;` : '';
    return `left:${this.x}px;top:${this.y}px;width:${this.w}px;${h}`;
  }
}

export const win = new WindowManager();
