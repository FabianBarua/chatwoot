<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { DonutChart } from '@chatwoot/viz';
import InsightPanel from '../agentInsights/InsightPanel.vue';
import {
  COLORS,
  DONUT_CHART_CLASS,
  formatCount,
} from '../agentInsights/chartTheme';
import { outcomeRate } from './botSchedule';

// How the conversations that reached the bot in the period ended: a donut with the outcomes
// and a funnel with each outcome's share of the conversations.
const props = defineProps({
  summary: { type: Object, default: () => ({}) },
});

const { t } = useI18n();

const total = computed(() => props.summary.conversations_count || 0);

const OUTCOMES = [
  {
    key: 'bot_resolved_count',
    label: 'RESOLVED',
    color: COLORS.online,
    bar: 'bg-n-teal-9',
  },
  {
    key: 'handoff_count',
    label: 'HANDED_OFF',
    color: COLORS.primary,
    bar: 'bg-n-blue-9',
  },
  {
    key: 'taken_over_count',
    label: 'TAKEN_OVER',
    color: COLORS.secondary,
    bar: 'bg-n-iris-9',
  },
  {
    key: 'auto_resolved_count',
    label: 'INACTIVITY',
    color: COLORS.busy,
    bar: 'bg-n-amber-9',
  },
];

const donutData = computed(() => ({
  total: total.value,
  segments: OUTCOMES.map(outcome => ({
    id: outcome.key,
    label: t(`BOT_INSIGHTS.OUTCOMES.${outcome.label}`),
    value: props.summary[outcome.key] || 0,
    color: outcome.color,
  })).filter(segment => segment.value > 0),
}));

const funnel = computed(() => [
  {
    key: 'conversations_count',
    label: t('BOT_INSIGHTS.OUTCOMES.ATTENDED'),
    value: total.value,
    width: 100,
    bar: 'bg-n-slate-8',
  },
  ...OUTCOMES.map(outcome => ({
    key: outcome.key,
    label: t(`BOT_INSIGHTS.OUTCOMES.${outcome.label}`),
    value: props.summary[outcome.key] || 0,
    width: outcomeRate(props.summary, outcome.key) || 0,
    bar: outcome.bar,
  })),
]);
</script>

<template>
  <InsightPanel
    :title="$t('BOT_INSIGHTS.OUTCOMES.TITLE')"
    :description="$t('BOT_INSIGHTS.OUTCOMES.DESCRIPTION')"
  >
    <div
      v-if="total"
      class="grid items-center grid-cols-1 gap-8 lg:grid-cols-[minmax(0,22rem)_1fr]"
    >
      <DonutChart
        :data="donutData"
        :diameter="176"
        :thickness="22"
        :aria-label="$t('BOT_INSIGHTS.OUTCOMES.TITLE')"
        :class="DONUT_CHART_CLASS"
      >
        <template #center>
          <div class="flex flex-col items-center leading-tight">
            <span class="text-2xl font-medium tabular-nums text-n-slate-12">
              {{ formatCount(total) }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ $t('BOT_INSIGHTS.OUTCOMES.ATTENDED') }}
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
            <span class="text-sm text-n-slate-12">{{ step.label }}</span>
            <span class="text-sm tabular-nums text-n-slate-11">
              <span class="font-medium text-n-slate-12">
                {{ formatCount(step.value) }}
              </span>
              <span
                v-if="step.key !== 'conversations_count'"
                class="ms-1.5 text-xs"
              >
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
      {{ $t('BOT_INSIGHTS.OUTCOMES.EMPTY') }}
    </p>
  </InsightPanel>
</template>
