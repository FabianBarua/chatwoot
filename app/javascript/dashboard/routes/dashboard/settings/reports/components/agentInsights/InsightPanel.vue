<script setup>
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
});
</script>

<template>
  <section
    class="flex flex-col min-w-0 rounded-xl outline outline-1 outline-n-container bg-n-solid-2"
  >
    <header class="flex items-start justify-between gap-3 px-5 pt-4">
      <div class="flex flex-col min-w-0 gap-0.5">
        <h3 class="text-sm font-medium text-n-slate-12">{{ title }}</h3>
        <p v-if="description" class="text-xs text-n-slate-11">
          {{ description }}
        </p>
      </div>
      <slot name="actions" />
    </header>
    <div class="min-w-0 px-5 pt-4 pb-5">
      <slot />
    </div>
  </section>
</template>
