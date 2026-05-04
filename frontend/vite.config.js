import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  base: '/',
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api/books': {
        target: 'http://localhost:5001',
        changeOrigin: true,
      },
      '/api/auth': {
        target: 'http://localhost:5002',
        changeOrigin: true,
      },
      '/api/reviews': {
        target: 'http://localhost:5003',
        changeOrigin: true,
      },
    }
  }
})
