import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    react(),
  ],

  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/setupTests.js',
    exclude: ['**/node_modules/**', '**/e2e/**'],

    // Give asynchronous React tests enough time in CI.
    testTimeout: 20000,
    hookTimeout: 20000,

    // Run tests sequentially to avoid shared mock/localStorage/API state
    // leaking between workers.
    pool: 'forks',
    poolOptions: {
      forks: {
        singleFork: true,
      },
    },

    coverage: {
      provider: 'v8',
    },
  },
})