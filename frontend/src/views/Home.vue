<script setup lang="ts">
import viteLogo from '@/assets/vite.svg'
</script>

<template>
  <main class="mx-auto max-w-5xl p-8 text-center">
    <!-- logo -->
    <div class="mb-8 flex items-center justify-center gap-4">
      <img :src="viteLogo" alt="Vite" class="h-10 w-auto" />
    </div>

    <h1 class="text-4xl font-extrabold tracking-tight">You did it!</h1>
    <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
      Vue 3 + Vite + Tailwind is up and running.
    </p>

    <section class="mt-10 grid gap-4 text-left md:grid-cols-2">
      <a
        href="https://vuejs.org/guide/introduction.html"
        target="_blank"
        rel="noreferrer"
        class="group rounded-2xl border border-gray-200 bg-white/60 p-6 shadow-sm backdrop-blur transition hover:shadow-md dark:border-gray-700 dark:bg-white/5"
      >
        <h2 class="flex items-center gap-2 text-lg font-semibold">
          Vue Docs
          <span class="transition group-hover:translate-x-0.5">→</span>
        </h2>
        <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Learn the fundamentals and best practices.
        </p>
      </a>

      <a
        href="https://vitejs.dev/guide/"
        target="_blank"
        rel="noreferrer"
        class="group rounded-2xl border border-gray-200 bg-white/60 p-6 shadow-sm backdrop-blur transition hover:shadow-md dark:border-gray-700 dark:bg-white/5"
      >
        <h2 class="flex items-center gap-2 text-lg font-semibold">
          Vite Guide
          <span class="transition group-hover:translate-x-0.5">→</span>
        </h2>
        <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Dev server, HMR, and build configuration.
        </p>
      </a>

      <a
        href="https://router.vuejs.org/"
        target="_blank"
        rel="noreferrer"
        class="group rounded-2xl border border-gray-200 bg-white/60 p-6 shadow-sm backdrop-blur transition hover:shadow-md dark:border-gray-700 dark:bg-white/5"
      >
        <h2 class="flex items-center gap-2 text-lg font-semibold">
          Vue Router
          <span class="transition group-hover:translate-x-0.5">→</span>
        </h2>
        <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Official routing for single-page applications.
        </p>
      </a>

      <a
        href="https://pinia.vuejs.org/"
        target="_blank"
        rel="noreferrer"
        class="group rounded-2xl border border-gray-200 bg-white/60 p-6 shadow-sm backdrop-blur transition hover:shadow-md dark:border-gray-700 dark:bg-white/5"
      >
        <h2 class="flex items-center gap-2 text-lg font-semibold">
          Pinia
          <span class="transition group-hover:translate-x-0.5">→</span>
        </h2>
        <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
          State management for Vue with a simple API.
        </p>
      </a>

      <a
        href="https://vuejs.org/guide/scaling-up/sfc.html#single-file-components"
        target="_blank"
        rel="noreferrer"
        class="group rounded-2xl border border-gray-200 bg-white/60 p-6 shadow-sm backdrop-blur transition hover:shadow-md dark:border-gray-700 dark:bg-white/5"
      >
        <h2 class="flex items-center gap-2 text-lg font-semibold">
          Single-File Components
          <span class="transition group-hover:translate-x-0.5">→</span>
        </h2>
        <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Author components with &lt;template&gt;, &lt;script&gt;, &lt;style&gt;.
        </p>
      </a>

      <a
        href="https://devtools.vuejs.org/"
        target="_blank"
        rel="noreferrer"
        class="group rounded-2xl border border-gray-200 bg-white/60 p-6 shadow-sm backdrop-blur transition hover:shadow-md dark:border-gray-700 dark:bg-white/5"
      >
        <h2 class="flex items-center gap-2 text-lg font-semibold">
          Vue Devtools
          <span class="transition group-hover:translate-x-0.5">→</span>
        </h2>
        <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Inspect components, state, and performance.
        </p>
      </a>
    </section>

    <p class="mt-10 text-xs text-gray-500 dark:text-gray-400">
      Edit
      <code class="rounded bg-gray-100 px-1 py-0.5 dark:bg-white/10">src/views/Home.vue</code> to
      customize this page.
    </p>
  </main>
</template>
