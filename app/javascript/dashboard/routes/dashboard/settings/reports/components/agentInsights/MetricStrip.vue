<script setup>
import { computed } from 'vue';

// One panel with a grid of metrics separated by hairlines. Each item can show how it moved
// against the previous period ({ current, previous }), reading "lower is better" for times.
const props = defineProps({
  // [{ key, label, value, current?, previous?, lowerIsBetter?, hint? }]
  items: { type: Array, default: () => [] },
  columns: { type: String, default: 'grid-cols-2 md:grid-cols-4' },
  isLoading: { type: Boolean, default: false },
});

const change = item => {
  const { current, previous } = item;
  if (!Number.isFinite(current) || !Number.isFinite(previous) || !previous) {
    return null;
  }
  return Math.round(((current - previous) / previous) * 100);
};

const rows = computed(() =>
  props.items.map(item => {
    const delta = change(item);
    const improved = item.lowerIsBetter ? delta < 0 : delta > 0;
    let tone = 'text-n-slate-11';
    if (delta) tone = improved ? 'text-n-teal-11' : 'text-n-ruby-11';
    return { ...item, delta, tone };
  })
);
</script>

<template>
  <div
    class="grid overflow-hidden rounded-xl outline outline-1 outline-n-container gap-px bg-n-weak"
    :class="columns"
  >
    <div
      v-for="item in rows"
      :key="item.key"
      class="flex flex-col gap-1 px-4 py-3.5 bg-n-solid-2"
    >
      <span class="text-xs text-n-slate-11">{{ item.label }}</span>
      <div class="flex items-baseline gap-2">
        <span
          v-if="isLoading"
          class="w-16 h-6 rounded bg-n-slate-3 animate-pulse"
        />
        <span
          v-else
          class="text-xl font-medium leading-tight tabular-nums text-n-slate-12"
        >
          {{ item.value }}
        </span>
        <span
          v-if="!isLoading && item.delta !== null"
          v-tooltip.top="$t('AGENT_INSIGHTS.VS_PREVIOUS')"
          class="text-xs font-medium tabular-nums"
          :class="item.tone"
        >
          {{ item.delta > 0 ? `+${item.delta}` : item.delta }}%
        </span>
      </div>
      <span v-if="item.hint" class="text-xs text-n-slate-10">
        {{ item.hint }}
      </span>
    </div>
  </div>
</template>
