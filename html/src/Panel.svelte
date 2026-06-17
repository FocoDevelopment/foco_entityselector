<script>
  import { store, copyText } from './inspector.svelte.js';
  import { win } from './windowManager.svelte.js';
  import { ICON_PATHS } from './icons.js';
  import Svg from './Svg.svelte';

  // Position the window the first time it opens this session.
  win.ensurePlaced();

  // Don't start a drag when grabbing an interactive control in the header.
  function headerPointerDown(e) {
    if (e.target.closest('button')) return;
    win.startDrag(e);
  }

  // -- Type mapping -----------------------------------------
  function typeKey(t) {
    const s = (t || '').toLowerCase();
    if (s === 'vehicle') return 'veh';
    if (s === 'ped')     return 'ped';
    if (s === 'object')  return 'obj';
    return 'unk';
  }
  const iconFor = { veh: 'vehicle', ped: 'ped', obj: 'object', unk: 'unknown' };

  function healthColor(hp, max) {
    const pct = max > 0 ? hp / max : 1;
    if (pct < 0.25) return 'var(--err)';
    if (pct < 0.6)  return 'var(--warn)';
    return 'var(--ok)';
  }
  function vehColor(v) {
    if (v >= 900) return 'var(--ok)';
    if (v >= 500) return 'var(--warn)';
    return 'var(--err)';
  }

  // -- Copy with checkmark feedback -------------------------
  let copied = $state({});
  function copy(key, text) {
    if (copyText(text)) {
      copied = { ...copied, [key]: true };
      setTimeout(() => (copied = { ...copied, [key]: false }), 900);
    }
  }

  let d = $derived(store.entity || {});
  let tk = $derived(typeKey(d.entityType));
  let isVeh = $derived(tk === 'veh');
  let isPed = $derived(tk === 'ped');
  let canDelete = $derived(!(isPed && d.extras && d.extras.isPlayer));
</script>

<div
  id="lime-window"
  class="panel t-{tk}"
  class:frozen={store.frozen}
  class:dragging={win.dragging}
  class:resizing={win.resizing}
  style={win.style}
>
  <!-- Header doubles as the draggable title bar -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="head" onpointerdown={headerPointerDown}>
    <div class="chip">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
           stroke-linecap="round" stroke-linejoin="round">
        {@html ICON_PATHS[iconFor[tk]]}
      </svg>
    </div>

    <div class="head-text">
      <div class="kicker">{d.entityType || 'Entity'} Inspector</div>
      <div class="model-row">
        <h1 class="model" title={d.modelName || ''}>{d.modelName || '—'}</h1>
        <button class="mini" title="Copy model name" onclick={() => copy('model', d.modelName)}>
          <Svg name={copied.model ? 'check' : 'copy'} size={11} />
        </button>
      </div>
    </div>

    <button class="close" aria-label="Close" onclick={() => store.closePanel()}>
      <Svg name="close" size={13} width={2.5} />
    </button>
  </div>

  <!-- Scrollable body (so the window can be resized smaller than content) -->
  <div class="body">
  <!-- Primary data grid -->
  <div class="grid">
    <div class="cell">
      <div class="lbl">Entity ID</div>
      <div class="val mono">{d.handle ?? '—'}</div>
    </div>
    <div class="cell">
      <div class="lbl">
        <Svg name="hash" size={10} /> Model Hash
        <button class="mini push" title="Copy hash" onclick={() => copy('hash', d.modelHash)}>
          <Svg name={copied.hash ? 'check' : 'copy'} size={10} />
        </button>
      </div>
      <div class="val mono">{d.modelHash || '—'}</div>
    </div>
    <div class="cell">
      <div class="lbl"><Svg name="heart" size={10} /> Health</div>
      <div class="val" style="color:{healthColor(d.health ?? 0, d.maxHealth ?? 200)}">
        {d.health ?? '—'}<span class="dim">/{d.maxHealth ?? 200}</span>
      </div>
    </div>
    <div class="cell">
      <div class="lbl"><Svg name="compass" size={10} /> Heading</div>
      <div class="val mono">{d.heading ?? '—'}°</div>
    </div>
    <div class="cell">
      <div class="lbl"><Svg name="ruler" size={10} /> Distance</div>
      <div class="val mono">{d.distance ?? '—'}m</div>
    </div>
    <div class="cell">
      <div class="lbl"><Svg name="net" size={10} /> Network</div>
      <div class="val">
        <span class="tag" class:synced={d.networked}>{d.networked ? 'Synced' : 'Local'}</span>
      </div>
    </div>
  </div>

  <!-- Coordinates -->
  <div class="block">
    <div class="block-head">
      <span class="sec"><Svg name="pin" size={11} /> Coordinates</span>
      <button class="mini" title="Copy coords"
        onclick={() => copy('coords', `${d.pos?.x ?? 0}, ${d.pos?.y ?? 0}, ${d.pos?.z ?? 0}`)}>
        <Svg name={copied.coords ? 'check' : 'copy'} size={11} />
      </button>
    </div>
    <div class="coords">
      <div class="coord"><span class="axis x">X</span><span class="mono">{d.pos?.x ?? '—'}</span></div>
      <div class="coord"><span class="axis y">Y</span><span class="mono">{d.pos?.y ?? '—'}</span></div>
      <div class="coord"><span class="axis z">Z</span><span class="mono">{d.pos?.z ?? '—'}</span></div>
    </div>
  </div>

  <!-- Owner (networked only) -->
  {#if d.networked && d.netId}
    <div class="owner">
      <div class="owner-cell">
        <div class="owner-lbl">Net ID</div>
        <div class="owner-val mono">{d.netId}</div>
      </div>
      <div class="owner-cell">
        <div class="owner-lbl">Owner</div>
        <div class="owner-val">{d.owner || '—'}</div>
      </div>
    </div>
  {/if}

  <!-- Type-specific -->
  {#if isVeh && d.extras}
    <div class="block">
      <span class="sec sub"><Svg name="vehicle" size={11} /> Vehicle Health</span>
      <div class="stats">
        <div class="stat"><span>Body</span>  <span class="mono" style="color:{vehColor(d.extras.body ?? 0)}">{d.extras.body ?? '—'}</span></div>
        <div class="stat"><span>Engine</span><span class="mono" style="color:{vehColor(d.extras.engine ?? 0)}">{d.extras.engine ?? '—'}</span></div>
        <div class="stat"><span>Tank</span>  <span class="mono" style="color:{vehColor(d.extras.tank ?? 0)}">{d.extras.tank ?? '—'}</span></div>
      </div>
    </div>
  {:else if isPed && d.extras}
    <div class="block">
      <span class="sec sub"><Svg name="ped" size={11} /> Ped Info</span>
      <div class="stats">
        <div class="stat"><span>Armour</span><span class="mono">{d.extras.armour ?? '—'}</span></div>
        <div class="stat"><span>Is Player</span>
          <span class="mono" style="color:{d.extras.isPlayer ? 'var(--warn)' : 'var(--t1)'}">
            {d.extras.isPlayer ? 'YES' : 'NO'}
          </span>
        </div>
      </div>
    </div>
  {/if}
  </div><!-- /.body -->

  <!-- Actions (pinned) -->
  <div class="actions">
    <div class="row">
      <button class="act teleport" onclick={() => store.teleport()}>
        <Svg name="teleport" size={14} /> Teleport
      </button>
      <button class="act freeze" class:on={store.frozen} onclick={() => store.toggleFreeze()}>
        <Svg name="freeze" size={14} /> {store.frozen ? 'Unfreeze' : 'Freeze'}
      </button>
    </div>
    <button class="act delete" disabled={!canDelete} onclick={() => store.deleteEntity()}>
      <Svg name="trash" size={14} /> {canDelete ? 'Delete Entity' : 'Protected (Player)'}
    </button>
  </div>

  <div class="foot">
    <span><kbd>Esc</kbd> close</span>
    <span class="brand">Lime Studios</span>
  </div>

  <!-- Resize handles: 4 edges + 4 corners -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="rz rz-n"  onpointerdown={(e) => win.startResize(e, 'n')}></div>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="rz rz-s"  onpointerdown={(e) => win.startResize(e, 's')}></div>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="rz rz-e"  onpointerdown={(e) => win.startResize(e, 'e')}></div>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="rz rz-w"  onpointerdown={(e) => win.startResize(e, 'w')}></div>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="rz rz-ne" onpointerdown={(e) => win.startResize(e, 'ne')}></div>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="rz rz-nw" onpointerdown={(e) => win.startResize(e, 'nw')}></div>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="rz rz-se" onpointerdown={(e) => win.startResize(e, 'se')}></div>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="rz rz-sw" onpointerdown={(e) => win.startResize(e, 'sw')}></div>
</div>

<style>
  .panel {
    position: fixed;
    display: flex;
    flex-direction: column;
    max-height: calc(100vh - 16px);
    padding: 14px 16px 12px;
    background: var(--bg);
    border: 1px solid var(--b0);
    border-left: 3px solid var(--type, var(--lime));
    border-radius: 6px;
    box-shadow: var(--shadow);
    animation: slideIn 0.28s var(--expo) both;
    will-change: transform, opacity;
  }
  /* clip only the visual glow layer, not the handles */
  .panel::before { border-radius: 6px; }
  /* Suppress the entry animation while actively dragging/resizing. */
  .panel.dragging, .panel.resizing { animation: none; user-select: none; }
  .panel.dragging { cursor: grabbing; }

  /* Scrollable content region */
  .body {
    flex: 1 1 auto;
    min-height: 0;
    overflow-y: auto;
    overflow-x: hidden;
    margin: 0 -4px;
    padding: 0 4px;
    scrollbar-width: thin;
    scrollbar-color: rgba(255,255,255,0.18) transparent;
  }
  .body::-webkit-scrollbar { width: 7px; }
  .body::-webkit-scrollbar-thumb {
    background: rgba(255,255,255,0.16);
    border-radius: 4px;
  }
  .body::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.28); }

  /* Accent is always lime green regardless of entity type or freeze
     state. (The type is still conveyed by the header icon.) */
  .panel.t-veh,
  .panel.t-ped,
  .panel.t-obj,
  .panel.t-unk,
  .panel.frozen {
    --type: var(--lime);
    --type-bg: var(--lime-g);
    --type-chip: rgba(74, 222, 128, 0.14);
  }

  /* faint type-tinted glow, like lime_notify glass */
  .panel::before {
    content: '';
    position: absolute; inset: 0;
    background: radial-gradient(ellipse 70% 55% at 0% 0%, var(--type-bg, transparent) 0%, transparent 60%);
    pointer-events: none;
    opacity: 0.9;
  }
  .panel > * { position: relative; }

  /* Header */
  .head {
    display: flex;
    align-items: center;
    gap: 11px;
    margin-bottom: 13px;
    flex-shrink: 0;
    cursor: grab;
    touch-action: none;
  }
  .panel.dragging .head { cursor: grabbing; }
  /* keep buttons in the header clickable with a normal cursor */
  .head button { cursor: pointer; }
  .chip {
    flex-shrink: 0;
    width: 38px; height: 38px;
    display: flex; align-items: center; justify-content: center;
    border-radius: 6px;
    color: var(--type, var(--lime));
    background: var(--type-chip, rgba(255,255,255,0.05));
    border: 1px solid color-mix(in srgb, var(--type, #fff) 30%, transparent);
  }
  .chip svg { width: 19px; height: 19px; }

  .head-text { flex: 1; min-width: 0; }
  .kicker {
    font-size: 9px;
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--type, var(--t2));
    opacity: 0.85;
    margin-bottom: 3px;
  }
  .model-row {
    display: flex;
    align-items: center;
    gap: 5px;
    min-width: 0;
  }
  .model {
    font-size: 14px;
    font-weight: 700;
    letter-spacing: -0.01em;
    color: var(--t0);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    min-width: 0;
  }

  .mini {
    display: inline-flex;
    align-items: center; justify-content: center;
    padding: 3px;
    border: none;
    background: transparent;
    border-radius: 4px;
    color: var(--t2);
    cursor: pointer;
    transition: color 0.15s, background 0.15s;
    flex-shrink: 0;
  }
  .mini:hover { color: var(--t0); background: rgba(255,255,255,0.08); }
  .mini.push { margin-left: auto; }

  .close {
    flex-shrink: 0;
    width: 24px; height: 24px;
    display: flex; align-items: center; justify-content: center;
    border: none; background: transparent;
    border-radius: 5px;
    color: rgba(255,255,255,0.25);
    cursor: pointer;
    transition: background 0.15s, color 0.15s;
  }
  .close:hover { background: rgba(255,255,255,0.08); color: rgba(255,255,255,0.6); }

  /* Grid */
  .grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    border: 1px solid var(--b0);
    border-radius: 6px;
    overflow: hidden;
    background: var(--bg-soft);
  }
  .cell {
    padding: 9px 12px;
    border-bottom: 1px solid var(--b0);
    border-right: 1px solid var(--b0);
    min-width: 0;
  }
  .cell:nth-child(2n) { border-right: none; }
  .cell:nth-last-child(-n+2) { border-bottom: none; }

  .lbl {
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 9px;
    font-weight: 700;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: var(--t2);
    margin-bottom: 5px;
  }
  .val {
    font-size: 13.5px;
    font-weight: 600;
    color: var(--t0);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .val .dim { color: var(--t2); font-weight: 500; }

  .tag {
    display: inline-block;
    padding: 2px 9px;
    border-radius: 5px;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.03em;
    background: rgba(255,255,255,0.05);
    border: 1px solid var(--b1);
    color: var(--t1);
  }
  .tag.synced {
    color: var(--lime);
    background: var(--lime-g);
    border-color: var(--lime-b);
  }

  /* Blocks */
  .block { margin-top: 12px; }
  .block-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 7px;
  }
  .sec {
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 9px;
    font-weight: 700;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--t2);
  }
  .sec.sub { margin-bottom: 7px; }

  /* Coordinates */
  .coords {
    display: flex;
    background: var(--bg-soft);
    border: 1px solid var(--b0);
    border-radius: 6px;
    overflow: hidden;
  }
  .coord {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 11px;
    border-right: 1px solid var(--b0);
    font-size: 12px;
  }
  .coord:last-child { border-right: none; }
  .coord .mono { color: var(--t1); }
  .axis { font-size: 10px; font-weight: 800; letter-spacing: 0.05em; }
  .axis.x { color: var(--err); }
  .axis.y { color: var(--ok); }
  .axis.z { color: var(--blue); }

  /* Owner */
  .owner {
    display: flex;
    gap: 10px;
    margin-top: 12px;
    padding: 10px 12px;
    background: var(--bg-soft);
    border: 1px solid var(--b0);
    border-radius: 6px;
  }
  .owner-cell { flex: 1; min-width: 0; }
  .owner-lbl {
    font-size: 9px; font-weight: 700;
    letter-spacing: 0.07em; text-transform: uppercase;
    color: var(--t2); margin-bottom: 3px;
  }
  .owner-val {
    font-size: 13px; font-weight: 600;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }

  /* Stats */
  .stats {
    border: 1px solid var(--b0);
    border-radius: 6px;
    overflow: hidden;
    background: var(--bg-soft);
  }
  .stat {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 12px;
    border-bottom: 1px solid var(--b0);
    font-size: 12.5px;
  }
  .stat:last-child { border-bottom: none; }
  .stat span:first-child { color: var(--t1); }
  .stat .mono { font-weight: 700; }

  /* Actions */
  .actions {
    margin-top: 13px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    gap: 7px;
  }
  .row { display: flex; gap: 7px; }
  .act {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 7px;
    padding: 10px 14px;
    border-radius: 6px;
    border: 1px solid var(--b1);
    background: rgba(255,255,255,0.04);
    color: var(--t1);
    font-family: var(--sans);
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    cursor: pointer;
    transition: background 0.15s, color 0.15s, border-color 0.15s, transform 0.08s;
  }
  .act:hover { background: rgba(255,255,255,0.07); color: var(--t0); }
  .act:active { transform: scale(0.97); }

  .act.teleport {
    background: var(--lime-g);
    border-color: var(--lime-b);
    color: var(--lime);
  }
  .act.teleport:hover { background: rgba(74,222,128,0.2); }

  .act.freeze.on {
    background: rgba(74,222,128,0.14);
    border-color: var(--lime-b);
    color: var(--lime);
  }

  .act.delete {
    background: rgba(248,113,113,0.12);
    border-color: rgba(248,113,113,0.3);
    color: var(--err);
  }
  .act.delete:hover:not(:disabled) { background: rgba(248,113,113,0.22); }
  .act.delete:disabled { opacity: 0.4; cursor: not-allowed; }

  /* Footer */
  .foot {
    margin-top: 11px;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 10px;
    color: var(--t2);
  }
  .foot .brand {
    font-weight: 800;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--lime);
    opacity: 0.65;
  }
  kbd {
    display: inline-flex;
    align-items: center;
    padding: 0 5px;
    height: 16px;
    background: rgba(255,255,255,0.06);
    border: 1px solid var(--b1);
    border-radius: 4px;
    font-size: 9px;
    font-weight: 700;
    font-family: var(--mono);
    color: var(--t1);
  }

  /* Resize handles — kept inside the panel's clip region (the panel
     uses overflow:hidden), sitting on the inner edge. z-index above all
     content so pointer events always reach them. */
  .rz { position: absolute; z-index: 50; touch-action: none; }
  .rz-n  { top: -3px; left: 12px; right: 12px; height: 8px; cursor: ns-resize; }
  .rz-s  { bottom: -3px; left: 12px; right: 12px; height: 8px; cursor: ns-resize; }
  .rz-e  { top: 12px; bottom: 12px; right: -3px; width: 8px; cursor: ew-resize; }
  .rz-w  { top: 12px; bottom: 12px; left: -3px; width: 8px; cursor: ew-resize; }
  .rz-ne { top: -4px; right: -4px; width: 16px; height: 16px; cursor: nesw-resize; }
  .rz-nw { top: -4px; left: -4px;  width: 16px; height: 16px; cursor: nwse-resize; }
  .rz-se { bottom: -4px; right: -4px; width: 16px; height: 16px; cursor: nwse-resize; }
  .rz-sw { bottom: -4px; left: -4px;  width: 16px; height: 16px; cursor: nesw-resize; }

  /* Subtle visible grip on the SE corner */
  .rz-se::after {
    content: '';
    position: absolute;
    right: 3px; bottom: 3px;
    width: 6px; height: 6px;
    border-right: 2px solid var(--type, var(--lime));
    border-bottom: 2px solid var(--type, var(--lime));
    opacity: 0.5;
    border-bottom-right-radius: 3px;
  }

  @keyframes slideIn {
    from { transform: translate3d(-32px, 0, 0); opacity: 0; }
    to   { transform: translate3d(0, 0, 0);      opacity: 1; }
  }
</style>
