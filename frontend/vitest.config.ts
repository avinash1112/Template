import { fileURLToPath } from 'node:url'
import { mergeConfig, defineConfig, configDefaults } from 'vitest/config'
import viteConfig from './vite.config'

const baseViteConfig =
  typeof viteConfig === 'function'
    ? viteConfig({ command: 'serve', mode: 'test' })
    : viteConfig

export default mergeConfig(
  baseViteConfig,
  defineConfig({
    test: {
      environment: 'jsdom',
      exclude: [...configDefaults.exclude, 'e2e/**'],
      root: fileURLToPath(new URL('./', import.meta.url)),
      // optional niceties:
      // globals: true,
      // css: true,
    },
  }),
)
