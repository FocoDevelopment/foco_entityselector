<script>
  import { store } from './inspector.svelte.js';
  import Svg from './Svg.svelte';
</script>

{#if store.toast}
  <div class="toast" class:ok={store.toast.ok} class:err={!store.toast.ok}>
    <div class="t-icon">
      <Svg name={store.toast.ok ? 'check' : 'alert'} size={15} />
    </div>
    <span class="t-msg">{store.toast.msg}</span>
  </div>
{/if}

<style>
  .toast {
    position: fixed;
    left: 50%;
    bottom: 26px;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 16px 10px 10px;
    border-radius: 6px;
    background: #111317;
    border: 1px solid var(--b0);
    border-left: 3px solid currentColor;
    box-shadow: var(--shadow);
    pointer-events: none;
    z-index: 50;
    animation: toastUp 0.28s var(--expo) both;
  }
  .toast.ok  { color: var(--ok);  background: var(--c-obj-bg); border-color: rgba(74,222,128,0.3); }
  .toast.err { color: var(--err); background: #1a1113; border-color: rgba(248,113,113,0.3); }

  .t-icon {
    flex-shrink: 0;
    width: 30px; height: 30px;
    display: flex; align-items: center; justify-content: center;
    border-radius: 5px;
    background: rgba(255,255,255,0.05);
    border: 1px solid rgba(255,255,255,0.08);
  }
  .toast.ok  .t-icon { background: var(--c-obj-chip); border-color: rgba(74,222,128,0.3); }
  .toast.err .t-icon { background: #331a1c;           border-color: rgba(248,113,113,0.3); }

  .t-msg {
    font-size: 12.5px;
    font-weight: 600;
    color: var(--t0);
    letter-spacing: 0.01em;
  }

  @keyframes toastUp {
    from { transform: translateX(-50%) translateY(16px); opacity: 0; }
    to   { transform: translateX(-50%) translateY(0);     opacity: 1; }
  }
</style>
