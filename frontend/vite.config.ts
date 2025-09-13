import { fileURLToPath, URL } from 'node:url'
import { defineConfig, loadEnv, type PluginOption, type ViteDevServer, type PreviewServer } from 'vite'
import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import vueJsx from '@vitejs/plugin-vue-jsx'
import vueDevTools from 'vite-plugin-vue-devtools'


function rewriteCliUrlsPlugin(publicHost: string): PluginOption {

  const stripAnsi = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '')

  // Match localhost/127.x/IPv6/10.x/172.16-31.x/192.168.x with optional port (keep the path after it)
  const URL_RE =
    /https?:\/\/(?:(?:localhost)|(?:127(?:\.\d+){3})|(?:\[[^\]]+\])|(?:10(?:\.\d+){3})|(?:172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})|(?:192\.168(?:\.\d{1,3}){2})|\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?(?=\/)/gi

  const shouldRewriteLine = (plainLine: string) => {
    // Only rewrite Local + DevTools lines; leave Network lines intact
    return (
      plainLine.includes('Local:') ||
      plainLine.includes('Vue DevTools:')
    )
  }

  const rewriteChunk = (chunk: any) => {
    const raw = typeof chunk === 'string' ? chunk : chunk?.toString?.() ?? ''
    if (!raw) return chunk

    const lines = raw.split(/\r?\n/)
    const outLines = lines.map((line: string) => {
      const plain = stripAnsi(line)
      if (!shouldRewriteLine(plain)) return line
      return plain.replace(URL_RE, `https://${publicHost}`)
    })

    return outLines.join('\n')
  }

  return {
    name: 'rewrite-cli-urls',
    apply: 'serve' as const,
    enforce: 'pre' as const,
    configureServer(server: ViteDevServer) {
      const origOut = process.stdout.write.bind(process.stdout)
      const origErr = process.stderr.write.bind(process.stderr)

      process.stdout.write = (c: any, enc?: any, cb?: any) => origOut(rewriteChunk(c), enc, cb)
      process.stderr.write = (c: any, enc?: any, cb?: any) => origErr(rewriteChunk(c), enc, cb)

      server.httpServer?.on('close', () => {
        process.stdout.write = origOut
        process.stderr.write = origErr
      })

    },

  }

}



function rewriteCliUrlsPreviewPlugin(publicHost: string, previewPort: number): PluginOption {
  const stripAnsi = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '')
  const URL_RE =
    /https?:\/\/(?:(?:localhost)|(?:127(?:\.\d+){3})|(?:\[[^\]]+\])|(?:10(?:\.\d+){3})|(?:172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})|(?:192\.168(?:\.\d{1,3}){2})|\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?(?=\/)/gi

  const rewriteChunk = (chunk: unknown) => {
    const raw = typeof chunk === 'string' ? chunk : (chunk as any)?.toString?.() ?? ''
    if (!raw) return chunk
    const lines = raw.split(/\r?\n/)
    const out = lines
      .map((line: string) => {
        const plain = stripAnsi(line)
        // only touch the Local line; leave Network lines intact
        return plain.includes('Local:')
          ? plain.replace(URL_RE, `http://${publicHost}:${previewPort}`)
          : line
      })
      .join('\n')
    return out
  }

  return {
    name: 'rewrite-cli-urls-preview',
    apply: 'serve' as const,
    enforce: 'pre' as const,
    configurePreviewServer(server: PreviewServer) {
      const origOut = process.stdout.write.bind(process.stdout)
      const origErr = process.stderr.write.bind(process.stderr)
      process.stdout.write = (c: any, enc?: any, cb?: any) => origOut(rewriteChunk(c), enc, cb)
      process.stderr.write = (c: any, enc?: any, cb?: any) => origErr(rewriteChunk(c), enc, cb)
      server.httpServer?.on('close', () => {
        process.stdout.write = origOut
        process.stderr.write = origErr
      })
    },
  }
}


export default defineConfig(({ mode }) => {

  // load all vars from .env files (not only VITE_*), but only VITE_* will be exposed to the client
  const env = loadEnv(mode, process.cwd(), '')

  // The public hostname the browser uses (front-end domain behind the proxy)
  const HMR_HOST = env.HOST_NAME

  // Container-side port Vite listens on
  const CONTAINER_PORT = Number(env.CONTAINER_PORT)

  // Browser side port to preview build app
  const PREVIEW_PORT = Number(env.VITE_PREVIEW_PORT)

  // URL Base base path
  const PUBLIC_BASE = env.VITE_PUBLIC_BASE

  return {
    plugins: [
      tailwindcss(),
      vue(),
      vueJsx(),
      vueDevTools(),
      rewriteCliUrlsPlugin(HMR_HOST),
      rewriteCliUrlsPreviewPlugin(HMR_HOST, PREVIEW_PORT),
    ],

    base: PUBLIC_BASE,

    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      }
    },

    server: {

      // Vite listens on the container's network interface
      host: '0.0.0.0',
      port: CONTAINER_PORT,
      strictPort: true,

      // Allow dev hostname (and local fallbacks)
      allowedHosts: [HMR_HOST, 'localhost', '127.0.0.1'],

      // Origin is used for asset and HMR URLs that Vite emits
      origin: `https://${HMR_HOST}`,

      // HMR config
      hmr: {
        protocol: 'wss',
        host: HMR_HOST,
        clientPort: 443
        // leave `port` undefined so WS binds to the same container port
      },

    },

    preview: {
      host: '0.0.0.0',
      port: PREVIEW_PORT
    },

    build: {
      outDir: 'dist',
      sourcemap: mode !== 'production'
    },

  }

})
