<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { BarChart } from '@chatwoot/viz';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import InsightPanel from './InsightPanel.vue';
import MetricStrip from './MetricStrip.vue';
import ChartLegend from './ChartLegend.vue';
import {
  BAR_CHART_CLASS,
  COLORS,
  STATUS_DOT_CLASSES,
  formatCount,
  formatDuration,
  formatHours,
  toHours,
} from './chartTheme';

const props = defineProps({
  rows: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['select']);

const { t } = useI18n();

const CHART_LIMIT = 12;

const sum = key =>
  props.rows.reduce((total, row) => total + (row[key] || 0), 0);

const average = key => {
  const values = props.rows.map(row => row[key]).filter(Number.isFinite);
  return values.length
    ? values.reduce((total, value) => total + value, 0) / values.length
    : null;
};

const csatAverage = computed(() => {
  const responses = sum('csat_count');
  if (!responses) return null;
  const weighted = props.rows.reduce(
    (total, row) => total + (row.csat_average || 0) * (row.csat_count || 0),
    0
  );
  return weighted / responses;
});

const kpis = computed(() => [
  {
    key: 'ATTENDED',
    value: formatCount(sum('attended_conversations_count')),
  },
  {
    key: 'RESOLVED',
    value: formatCount(sum('resolved_conversations_count')),
  },
  {
    key: 'MESSAGES_SENT',
    value: formatCount(sum('outgoing_messages_count')),
  },
  {
    key: 'FIRST_RESPONSE',
    value: formatDuration(average('avg_first_response_time')),
  },
  {
    key: 'ONLINE_HOURS',
    value: formatHours(toHours(sum('online_seconds') + sum('busy_seconds'))),
  },
  {
    key: 'CSAT',
    value: csatAverage.value ? `${csatAverage.value.toFixed(1)} / 5` : '--',
  },
  {
    key: 'OPEN_NOW',
    value: formatCount(sum('open_conversations')),
  },
  {
    key: 'UNATTENDED_NOW',
    value: formatCount(sum('unattended_conversations')),
  },
]);

const kpiItems = computed(() =>
  kpis.value.map(kpi => ({
    key: kpi.key,
    label: t(`AGENT_INSIGHTS.KPI.${kpi.key}`),
    value: kpi.value,
  }))
);

const firstName = name => (name || '').split(' ')[0];

const topBy = key =>
  [...props.rows]
    .sort((a, b) => (b[key] || 0) - (a[key] || 0))
    .slice(0, CHART_LIMIT);

const conversationsChart = computed(() => {
  const rows = topBy('attended_conversations_count');
  return {
    categories: rows.map(row => firstName(row.name)),
    series: [
      {
        id: 'attended',
        label: t('AGENT_INSIGHTS.SERIES.ATTENDED'),
        color: COLORS.primary,
        data: rows.map(row => row.attended_conversations_count || 0),
      },
      {
        id: 'resolved',
        label: t('AGENT_INSIGHTS.SERIES.RESOLVED'),
        color: COLORS.online,
        data: rows.map(row => row.resolved_conversations_count || 0),
      },
    ],
  };
});

const presenceChart = computed(() => {
  const rows = [...props.rows]
    .sort(
      (a, b) =>
        b.online_seconds + b.busy_seconds - (a.online_seconds + a.busy_seconds)
    )
    .slice(0, CHART_LIMIT);
  return {
    categories: rows.map(row => firstName(row.name)),
    series: [
      {
        id: 'online',
        label: t('AGENT_ACTIVITY_REPORTS.STATUS.online'),
        color: COLORS.online,
        data: rows.map(row => toHours(row.online_seconds)),
      },
      {
        id: 'busy',
        label: t('AGENT_ACTIVITY_REPORTS.STATUS.busy'),
        color: COLORS.busy,
        data: rows.map(row => toHours(row.busy_seconds)),
      },
    ],
  };
});

const hasConversations = computed(() =>
  props.rows.some(row => row.attended_conversations_count)
);
const hasPresence = computed(() =>
  props.rows.some(row => row.online_seconds || row.busy_seconds)
);

const COLUMNS = [
  { key: 'attended_conversations_count', format: formatCount },
  { key: 'resolved_conversations_count', format: formatCount },
  { key: 'outgoing_messages_count', format: formatCount },
  {
    key: 'avg_first_response_time',
    format: formatDuration,
    lowerIsBetter: true,
  },
  { key: 'avg_reply_time', format: formatDuration, lowerIsBetter: true },
  {
    key: 'online_seconds',
    format: (value, row) => formatHours(toHours(value + row.busy_seconds)),
  },
  {
    key: 'csat_average',
    format: value => (value ? value.toFixed(1) : '--'),
  },
  {
    key: 'open_conversations',
    format: (value, row) =>
      `${formatCount(value)} / ${formatCount(row.unattended_conversations)}`,
  },
];

const sortKey = ref('attended_conversations_count');
const sortDesc = ref(true);

const sortedRows = computed(() => {
  const direction = sortDesc.value ? -1 : 1;
  const value = row => {
    if (sortKey.value === 'name') return row.name?.toLowerCase() ?? '';
    const raw = row[sortKey.value];
    return Number.isFinite(raw) ? raw : null;
  };
  return [...props.rows].sort((a, b) => {
    const left = value(a);
    const right = value(b);
    if (left === right) return 0;
    if (left === null) return 1;
    if (right === null) return -1;
    return left > right ? direction : -direction;
  });
});

const sortBy = key => {
  if (sortKey.value === key) {
    sortDesc.value = !sortDesc.value;
  } else {
    sortKey.value = key;
    sortDesc.value = key !== 'name';
  }
};

const ariaSort = key => {
  if (sortKey.value !== key) return 'none';
  return sortDesc.value ? 'descending' : 'ascending';
};

const sortIcon = key => {
  if (sortKey.value !== key) return 'i-lucide-chevrons-up-down';
  return sortDesc.value ? 'i-lucide-chevron-down' : 'i-lucide-chevron-up';
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <MetricStrip :items="kpiItems" :is-loading="isLoading" />

    <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
      <InsightPanel
        :title="$t('AGENT_INSIGHTS.CHARTS.CONVERSATIONS_BY_AGENT')"
        :description="$t('AGENT_INSIGHTS.CHARTS.CONVERSATIONS_BY_AGENT_DESC')"
      >
        <div
          v-if="isLoading"
          class="h-60 rounded-lg bg-n-slate-3 animate-pulse"
        />
        <ChartLegend
          v-if="!isLoading && hasConversations"
          :series="conversationsChart.series"
        />
        <BarChart
          v-if="!isLoading && hasConversations"
          :data="conversationsChart"
          :height="240"
          :max-bar-width="20"
          :bar-gap="3"
          :aria-label="$t('AGENT_INSIGHTS.CHARTS.CONVERSATIONS_BY_AGENT')"
          :class="BAR_CHART_CLASS"
        />
        <p
          v-else-if="!isLoading"
          class="grid h-60 text-sm place-content-center text-n-slate-11"
        >
          {{ $t('AGENT_INSIGHTS.EMPTY_CHART') }}
        </p>
      </InsightPanel>
      <InsightPanel
        :title="$t('AGENT_INSIGHTS.CHARTS.HOURS_BY_AGENT')"
        :description="$t('AGENT_INSIGHTS.CHARTS.HOURS_BY_AGENT_DESC')"
      >
        <div
          v-if="isLoading"
          class="h-60 rounded-lg bg-n-slate-3 animate-pulse"
        />
        <ChartLegend
          v-if="!isLoading && hasPresence"
          :series="presenceChart.series"
        />
        <BarChart
          v-if="!isLoading && hasPresence"
          :data="presenceChart"
          stacked
          :height="240"
          :max-bar-width="28"
          :format-value="formatHours"
          :aria-label="$t('AGENT_INSIGHTS.CHARTS.HOURS_BY_AGENT')"
          :class="BAR_CHART_CLASS"
        />
        <p
          v-else-if="!isLoading"
          class="grid h-60 text-sm place-content-center text-n-slate-11"
        >
          {{ $t('AGENT_INSIGHTS.EMPTY_CHART') }}
        </p>
      </InsightPanel>
    </div>

    <InsightPanel
      :title="$t('AGENT_INSIGHTS.RANKING.TITLE')"
      :description="$t('AGENT_INSIGHTS.RANKING.DESCRIPTION')"
    >
      <div class="-mx-5 -mb-5 overflow-x-auto">
        <table class="w-full text-sm text-left whitespace-nowrap">
          <thead class="text-xs text-n-slate-11">
            <tr class="border-y border-n-weak">
              <th class="px-5 py-2.5 font-medium" :aria-sort="ariaSort('name')">
                <button
                  type="button"
                  class="inline-flex items-center gap-1 hover:text-n-slate-12"
                  @click="sortBy('name')"
                >
                  {{ $t('AGENT_INSIGHTS.RANKING.AGENT') }}
                  <Icon :icon="sortIcon('name')" class="size-3.5" />
                </button>
              </th>
              <th
                v-for="column in COLUMNS"
                :key="column.key"
                class="px-3 py-2.5 font-medium text-end"
                :aria-sort="ariaSort(column.key)"
              >
                <button
                  type="button"
                  class="inline-flex items-center gap-1 hover:text-n-slate-12"
                  @click="sortBy(column.key)"
                >
                  {{ $t(`AGENT_INSIGHTS.RANKING.COLUMNS.${column.key}`) }}
                  <Icon :icon="sortIcon(column.key)" class="size-3.5" />
                </button>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="isLoading">
              <td
                :colspan="COLUMNS.length + 1"
                class="px-5 py-8 text-center text-n-slate-11"
              >
                {{ $t('AGENT_INSIGHTS.LOADING') }}
              </td>
            </tr>
            <template v-else>
              <tr
                v-for="row in sortedRows"
                :key="row.id"
                class="border-b cursor-pointer border-n-weak last:border-b-0 hover:bg-n-alpha-1"
                @click="emit('select', row.id)"
              >
                <td class="px-5 py-2">
                  <div class="flex items-center gap-2">
                    <Avatar
                      :src="row.thumbnail"
                      :name="row.name"
                      :size="28"
                      rounded-full
                    />
                    <div class="flex flex-col min-w-0">
                      <span class="font-medium text-n-slate-12">
                        {{ row.name }}
                      </span>
                      <span
                        class="inline-flex items-center gap-1 text-xs text-n-slate-11"
                      >
                        <span
                          class="rounded-full size-1.5"
                          :class="
                            STATUS_DOT_CLASSES[row.current_status] ||
                            STATUS_DOT_CLASSES.offline
                          "
                        />
                        {{
                          $t(
                            `AGENT_ACTIVITY_REPORTS.STATUS.${row.current_status || 'offline'}`
                          )
                        }}
                      </span>
                    </div>
                  </div>
                </td>
                <td
                  v-for="column in COLUMNS"
                  :key="column.key"
                  class="px-3 py-2 tabular-nums text-end text-n-slate-12"
                >
                  {{ column.format(row[column.key], row) }}
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </InsightPanel>
  </div>
</template>
