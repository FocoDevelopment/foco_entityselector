<script>
  import { SVG } from './icons.js';
  let { name, size = 14, width = 2 } = $props();
</script>

<svg
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width={width}
  stroke-linecap="round"
  stroke-linejoin="round"
>
  {@html SVG[name] || ''}
</svg>
