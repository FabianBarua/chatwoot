<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { DonutChart } from '@chatwoot/viz';
import InsightPanel from './InsightPanel.vue';
import { COLORS, DONUT_CHART_CLASS, formatCount } from './chartTheme';

const props = defineProps({
  workload: { type: Object, default: () => ({}) },
});

const { t } = useI18n();

const assigned = computed(() => props.workload.assigned || 0);
const inAttention = computed(
  () =>
    (props.workload.open || 0) +
    (props.workload.pending || 0) +
    (props.workload.snoozed || 0)
);

const percent = value =>
  assigned.value ? Math.round((value / assigned.value) * 100) : 0;

const donutData = computed(() => ({
  total: assigned.value,
  segments: [
    {
      id: 'resolved',
      label: t('AGENT_INSIGHTS.WORKLOAD.RESOLVED'),
      value: props.workload.resolved || 0,
      color: COLORS.online,
    },
    {
      id: 'open',
      label: t('AGENT_INSIGHTS.WORKLOAD.OPEN'),
      value: props.workload.open || 0,
      color: COLORS.primary,
    },
    {
      id: 'pending',
      label: t('AGENT_INSIGHTS.WORKLOAD.PENDING'),
      value: props.workload.pending || 0,
      color: COLORS.secondary,
    },
    {
      id: 'snoozed',
      label: t('AGENT_INSIGHTS.WORKLOAD.SNOOZED'),
      value: props.workload.snoozed || 0,
      color: COLORS.muted,
    },
  ].filter(segment => segment.value > 0),
}));

const funnel = computed(() => [
  {
    key: 'assigned',
    label: t('AGENT_INSIGHTS.WORKLOAD.ASSIGNED'),
    value: assigned.value,
    width: 100,
    bar: 'bg-n-slate-8',
  },
  {
    key: 'attended',
    label: t('AGENT_INSIGHTS.WORKLOAD.ATTENDED'),
    value: props.workload.attended || 0,
    width: percent(props.workload.attended || 0),
    bar: 'bg-n-slate-10',
  },
  {
    key: 'resolved',
    label: t('AGENT_INSIGHTS.WORKLOAD.RESOLVED'),
    value: props.workload.resolved || 0,
    width: percent(props.workload.resolved || 0),
    bar: 'bg-n-teal-9',
  },
  {
    key: 'in_attention',
    label: t('AGENT_INSIGHTS.WORKLOAD.IN_ATTENTION'),
    value: inAttention.value,
    width: percent(inAttention.value),
    bar: 'bg-n-blue-9',
    note: props.workload.waiting
      ? t('AGENT_INSIGHTS.WORKLOAD.WAITING_NOTE', {
          count: props.workload.waiting,
        })
      : '',
  },
]);
</script>

<template>
  <InsightPanel
    :title="$t('AGENT_INSIGHTS.WORKLOAD.TITLE')"
    :description="$t('AGENT_INSIGHTS.WORKLOAD.DESCRIPTION')"
  >
    <div
      v-if="assigned"
      class="grid items-center grid-cols-1 gap-8 lg:grid-cols-[minmax(0,22rem)_1fr]"
    >
      <DonutChart
        :data="donutData"
        :diameter="176"
        :thickness="22"
        :aria-label="$t('AGENT_INSIGHTS.WORKLOAD.TITLE')"
        :class="DONUT_CHART_CLASS"
      >
        <template #center>
          <div class="flex flex-col items-center leading-tight">
            <span class="text-2xl font-medium tabular-nums text-n-slate-12">
              {{ formatCount(assigned) }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ $t('AGENT_INSIGHTS.WORKLOAD.ASSIGNED') }}
            </span>
          </div>
        </template>
        <template #legend-item="{ label, formattedValue, formattedPercentage }">
          <span class="text-sm text-n-slate-11">{{ label }}</span>
          <span class="text-sm font-medium tabular-nums text-n-slate-12">
            {{ formattedValue }}
          </span>
          <span class="text-xs tabular-nums text-n-slate-10">
            {{ formattedPercentage }}
          </span>
        </template>
      </DonutChart>

      <ul class="flex flex-col gap-4 p-0 m-0 list-none">
        <li v-for="step in funnel" :key="step.key">
          <div class="flex items-baseline justify-between gap-3 mb-1.5">
            <span class="text-sm text-n-slate-12">
              {{ step.label }}
              <span
                v-if="step.note"
                class="ms-1.5 px-1.5 py-0.5 text-xs rounded-md bg-n-amber-3 text-n-amber-11"
              >
                {{ step.note }}
              </span>
            </span>
            <span class="text-sm tabular-nums text-n-slate-11">
              <span class="font-medium text-n-slate-12">
                {{ formatCount(step.value) }}
              </span>
              <span v-if="step.key !== 'assigned'" class="ms-1.5 text-xs">
                {{ `${step.width}%` }}
              </span>
            </span>
          </div>
          <div class="h-2.5 rounded-full bg-n-alpha-2">
            <div
              class="h-full rounded-full transition-[width] duration-500 ease-out"
              :class="step.bar"
              :style="{ width: `${step.width}%` }"
            />
          </div>
        </li>
      </ul>
    </div>
    <p v-else class="py-10 text-sm text-center text-n-slate-11">
      {{ $t('AGENT_INSIGHTS.WORKLOAD.EMPTY') }}
    </p>
  </InsightPanel>
</template>
