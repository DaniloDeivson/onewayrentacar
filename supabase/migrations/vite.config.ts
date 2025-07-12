import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  optimizeDeps: {
    exclude: ['lucide-react'],
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
    assetsDir: 'assets',
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          ui: ['@headlessui/react', 'lucide-react'],
          forms: ['react-hook-form', '@hookform/resolvers', 'zod'],
          charts: ['recharts'],
          supabase: ['@supabase/supabase-js'],
        },
        // Garantir extensões corretas para módulos
        entryFileNames: 'assets/[name]-[hash].js',
        chunkFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash].[ext]',
      },
    },
    chunkSizeWarningLimit: 1000,
    // Configurações específicas para Netlify
    target: 'es2015',
    minify: 'esbuild',
  },
  define: {
    global: 'globalThis',
  },
  // Configurações do servidor para desenvolvimento
  server: {
    host: true,
    port: 5173,
  },
  // Configurações de preview
  preview: {
    host: true,
    port: 4173,
  },
});
