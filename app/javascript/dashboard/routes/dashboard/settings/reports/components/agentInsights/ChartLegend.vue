<script setup>
defineProps({
  // [{ id, label, color }], the same series passed to the chart
  series: { type: Array, default: () => [] },
});
</script>

<template>
  <div class="flex flex-wrap items-center gap-x-4 gap-y-1 mb-3 text-xs">
    <span
      v-for="item in series"
      :key="item.id"
      class="inline-flex items-center gap-1.5 text-n-slate-11"
    >
      <span
        class="rounded-sm size-2.5"
        :style="{ backgroundColor: item.color }"
      />
      {{ item.label }}
    </span>
  </div>
</template>
