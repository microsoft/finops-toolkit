import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');

  // Split allowed hosts by comma, filter out empty strings
//   const allowedHosts = (env.VITE_ALLOWED_HOSTS || 'http://localhost:5173')
//     .split(',')
//     .map(h => h.trim())
//     .filter(Boolean);

  return {
    plugins: [react()],
    server: {
      allowedHosts: true,
      proxy: {
        '/api': {
          target: env.VITE_BACKEND_URL || 'http://127.0.0.1:8000',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api/, ''),
        },
      },
    },
  };
});
