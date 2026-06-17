<script>
  import { onMount } from 'svelte';
  import { store, initBridge } from './inspector.svelte.js';
  import Panel from './Panel.svelte';
  import Toast from './Toast.svelte';

  onMount(() => initBridge());
</script>

{#if store.open}
  <Panel />
{/if}
<Toast />
