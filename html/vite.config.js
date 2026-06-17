import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

// FiveM serves NUI from a local nui:// scheme, so we need:
//  - base: './'  -> relative asset paths
//  - predictable asset filenames (no hashes) for the fxmanifest files list
export default defineConfig({
  plugins: [svelte()],
  base: './',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    assetsDir: 'assets',
    rollupOptions: {
      output: {
        entryFileNames: 'assets/[name].js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name].[ext]',
      },
    },
  },
});
