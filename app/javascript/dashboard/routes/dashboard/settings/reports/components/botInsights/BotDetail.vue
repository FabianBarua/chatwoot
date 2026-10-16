<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { BarChart, DonutChart, HeatmapChart, LineChart } from '@chatwoot/viz';
import { CSAT_RATINGS } from 'shared/constants/messages';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import InsightPanel from '../agentInsights/InsightPanel.vue';
import MetricStrip from '../agentInsights/MetricStrip.vue';
import ChartLegend from '../agentInsights/ChartLegend.vue';
import BotOutcomePanel from './BotOutcomePanel.vue';
import {
  BAR_CHART_CLASS,
  COLORS,
  DONUT_CHART_CLASS,
  HEATMAP_CLASS,
  HEATMAP_COLORS,
  HEATMAP_QUANTILES,
  LINE_CHART_CLASS,
  formatCount,
  formatDuration,
} from '../agentInsights/chartTheme';
import { busiest, hourlySeries, outcomeRate, totalsBy } from './botSchedule';

// Dashboard of the agent bot, same structure as the agent dashboard (AgentDetail.vue):
// header with the current state, tabs, a metric strip and charts per tab.
const props = defineProps({
  insight: { type: Object, default: null },
  isLoading: { type: Boolean, default: false },
});

const { t, locale } = useI18n();

// Intl needs a BCP 47 tag (pt-BR), the app uses pt_BR
const intlLocale = computed(() => locale.value.replace('_', '-'));

const route = useRoute();
const router = useRouter();

const TAB_KEYS = ['summary', 'schedule', 'quality'];
const tabs = computed(() =>
  TAB_KEYS.map(key => ({
    value: key,
    label: t(`BOT_INSIGHTS.TABS.${key.toUpperCase()}`),
  }))
);
const activeTab = computed(() => {
  const index = TAB_KEYS.indexOf(route.query.tab);
  return index === -1 ? 0 : index;
});
const selectTab = tab => {
  router.replace({
    query: {
      ...route.query,
      tab: tab.value === 'summary' ? undefined : tab.value,
    },
  });
};

const WEEKDAYS = [1, 2, 3, 4, 5, 6, 0];
const HOURS = Array.from({ length: 24 }, (_, hour) => hour);
const hourLabel = hour => `${String(hour).padStart(2, '0')}h`;
// 2023-01-01 was a Sunday, so day N of that week is weekday N
const weekdayLabel = (weekday, style = 'short') =>
  new Intl.DateTimeFormat(intlLocale.value, { weekday: style }).format(
    new Date(2023, 0, 1 + weekday)
  );

const bots = computed(() => props.insight?.bots || []);
const inboxes = computed(() => props.insight?.inboxes || []);
const summary = computed(() => props.insight?.summary || {});
const previous = computed(() => props.insight?.previous_summary || {});
const daily = computed(() => props.insight?.daily || []);
const hourly = computed(() => props.insight?.hourly || []);

const formatRate = value => (value === null ? '--' : `${value}%`);

const metricItem = (key, format, options = {}) => {
  const now = options.value ? options.value(summary.value) : summary.value[key];
  const before = options.value
    ? options.value(previous.value)
    : previous.value[key];
  return {
    key,
    label: t(`BOT_INSIGHTS.METRICS.${key}`),
    value: format(now),
    current: now,
    previous: before,
    lowerIsBetter: !!options.lowerIsBetter,
  };
};

const rateItem = (key, countKey, options = {}) =>
  metricItem(key, formatRate, {
    value: source => outcomeRate(source, countKey),
    ...options,
  });

const summaryMetrics = computed(() => [
  metricItem('conversations_count', formatCount),
  metricItem('bot_resolved_count', formatCount),
  metricItem('handoff_count', formatCount),
  metricItem('taken_over_count', formatCount),
  metricItem('auto_resolved_count', formatCount, { lowerIsBetter: true }),
  metricItem('outgoing_messages_count', formatCount),
  metricItem('avg_resolution_time', formatDuration, { lowerIsBetter: true }),
  metricItem('avg_handoff_time', formatDuration, { lowerIsBetter: true }),
]);

const weekdayTotals = computed(() => totalsBy(hourly.value, 'weekday'));
const hourTotals = computed(() => totalsBy(hourly.value, 'hour'));
const busiestWeekday = computed(() => busiest(weekdayTotals.value));
const peakHour = computed(() => busiest(hourTotals.value));

const scheduleMetrics = computed(() => [
  {
    key: 'busiest_weekday',
    label: t('BOT_INSIGHTS.METRICS.busiest_weekday'),
    value: busiestWeekday.value
      ? weekdayLabel(busiestWeekday.value.key, 'long')
      : '--',
    hint: busiestWeekday.value
      ? t('BOT_INSIGHTS.CONVERSATIONS_HINT', {
          count: busiestWeekday.value.count,
        })
      : '',
  },
  {
    key: 'peak_hour',
    label: t('BOT_INSIGHTS.METRICS.peak_hour'),
    value: peakHour.value ? hourLabel(peakHour.value.key) : '--',
    hint: peakHour.value
      ? t('BOT_INSIGHTS.CONVERSATIONS_HINT', { count: peakHour.value.count })
      : '',
  },
  {
    key: 'avg_per_day',
    label: t('BOT_INSIGHTS.METRICS.avg_per_day'),
    value: daily.value.length
      ? (
          (summary.value.conversations_count || 0) / daily.value.length
        ).toLocaleString(intlLocale.value, { maximumFractionDigits: 1 })
      : '--',
  },
]);

const qualityMetrics = computed(() => [
  metricItem('csat_average', value =>
    value ? `${value.toFixed(1)} / 5` : '--'
  ),
  metricItem('csat_count', formatCount),
  {
    key: 'satisfaction_rate',
    label: t('BOT_INSIGHTS.METRICS.satisfaction_rate'),
    value: Number.isFinite(props.insight?.csat?.satisfaction_rate)
      ? `${props.insight.csat.satisfaction_rate}%`
      : '--',
  },
  rateItem('resolution_rate', 'bot_resolved_count'),
  rateItem('handoff_rate', 'handoff_count'),
  rateItem('inactivity_rate', 'auto_resolved_count', { lowerIsBetter: true }),
]);

const dayLabel = date =>
  new Intl.DateTimeFormat(intlLocale.value, {
    day: '2-digit',
    month: '2-digit',
  }).format(new Date(`${date}T00:00:00`));

const categories = computed(() => daily.value.map(day => dayLabel(day.date)));
const showValues = computed(() => daily.value.length <= 14);

const series = (id, labelKey, color, key) => ({
  id,
  label: t(`BOT_INSIGHTS.SERIES.${labelKey}`),
  color,
  data: daily.value.map(day => day[key]),
});

const conversationsChart = computed(() => ({
  categories: categories.value,
  series: [
    series('attended', 'ATTENDED', COLORS.muted, 'conversations_count'),
    series('resolved', 'RESOLVED', COLORS.online, 'bot_resolved_count'),
    series('handoff', 'HANDED_OFF', COLORS.primary, 'handoff_count'),
    series('inactivity', 'INACTIVITY', COLORS.busy, 'auto_resolved_count'),
  ],
}));

const messagesChart = computed(() => ({
  categories: categories.value,
  series: [
    {
      id: 'messages',
      label: t('BOT_INSIGHTS.SERIES.MESSAGES'),
      color: COLORS.secondary,
      pointBorderColor: 'rgb(var(--solid-2))',
      data: daily.value.map(day => day.outgoing_messages_count),
    },
  ],
}));

const byHourChart = computed(() => ({
  categories: HOURS.map(hourLabel),
  series: [
    {
      id: 'conversations',
      label: t('BOT_INSIGHTS.SERIES.CONVERSATIONS'),
      color: COLORS.primary,
      data: hourlySeries(hourly.value),
    },
  ],
}));

const hasAny = (...keys) => daily.value.some(day => keys.some(key => day[key]));

const heatmapData = computed(() => {
  const cells = new Map(
    hourly.value.map(cell => [`${cell.weekday}-${cell.hour}`, cell.count])
  );
  const columns = HOURS.map(hour => ({ id: hour, label: hourLabel(hour) }));
  return {
    columns,
    rows: WEEKDAYS.map(weekday => ({
      id: weekday,
      label: weekdayLabel(weekday),
      data: columns.map(({ id }) => {
        const value = cells.get(`${weekday}-${id}`);
        return value ? { value } : null;
      }),
    })),
  };
});

const hasHeatmap = computed(() => hourly.value.length > 0);

const csat = computed(() => props.insight?.csat || { ratings: [] });
const csatTotal = computed(() =>
  csat.value.ratings.reduce((total, item) => total + item.count, 0)
);
const csatCenter = computed(() => summary.value.csat_average);
const csatChart = computed(() => {
  const counts = Object.fromEntries(
    csat.value.ratings.map(item => [item.rating, item.count])
  );
  return {
    total: csatTotal.value,
    segments: [...CSAT_RATINGS]
      .sort((a, b) => b.value - a.value)
      .map(rating => ({
        id: rating.key,
        label: t(rating.translationKey),
        value: counts[rating.value] || 0,
        color: rating.color,
      })),
  };
});

const barList = items => {
  const max = Math.max(...items.map(item => item.count), 1);
  return items.map(item => ({ ...item, width: (item.count / max) * 100 }));
};
const lists = computed(() => [
  {
    key: 'DROP_OFF',
    items: barList(props.insight?.abandoned_steps || []),
    icon: 'i-lucide-log-out',
    bar: 'bg-n-amber-9',
  },
  {
    key: 'TITLES',
    items: barList(props.insight?.titles || []),
    icon: 'i-lucide-message-square-text',
    bar: 'bg-n-blue-9',
  },
  {
    key: 'LABELS',
    items: barList(props.insight?.labels || []),
    icon: 'i-lucide-tag',
    bar: 'bg-n-blue-9',
  },
]);
</script>

<template>
  <div v-if="isLoading && !insight" class="flex flex-col gap-4">
    <div class="h-24 rounded-xl bg-n-slate-3 animate-pulse" />
    <div class="h-64 rounded-xl bg-n-slate-3 animate-pulse" />
    <div class="h-24 rounded-xl bg-n-slate-3 animate-pulse" />
  </div>

  <div
    v-else-if="insight"
    class="flex flex-col gap-5 transition-opacity"
    :class="{ 'opacity-60': isLoading }"
  >
    <section
      class="flex flex-col gap-4 p-5 rounded-xl outline outline-1 outline-n-container bg-n-solid-2 md:flex-row md:items-center"
    >
      <div class="flex items-center -space-x-3">
        <Avatar
          v-for="bot in bots"
          :key="bot.id"
          :src="bot.thumbnail"
          :name="bot.name"
          :size="56"
          rounded-full
        />
        <Avatar
          v-if="!bots.length"
          :name="$t('BOT_INSIGHTS.NO_BOT_TITLE')"
          :size="56"
          rounded-full
        />
      </div>
      <div class="flex flex-col flex-1 min-w-0 gap-1">
        <div class="flex flex-wrap items-center gap-2">
          <h2 class="m-0 text-lg font-medium text-n-slate-12">
            {{
              bots.length
                ? bots.map(bot => bot.name).join(', ')
                : $t('BOT_INSIGHTS.NO_BOT_TITLE')
            }}
          </h2>
          <span
            class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
          >
            {{ $t('BOT_INSIGHTS.BOT_BADGE') }}
          </span>
        </div>
        <span
          v-if="inboxes.length"
          class="inline-flex items-center gap-1.5 text-sm text-n-slate-11"
        >
          <Icon icon="i-lucide-inbox" class="size-3.5 text-n-slate-10" />
          {{ inboxes.map(inbox => inbox.name).join(', ') }}
        </span>
        <span v-else class="text-sm text-n-amber-11">
          {{ $t('BOT_INSIGHTS.NO_BOT') }}
        </span>
      </div>
      <dl class="flex gap-6 m-0">
        <div class="flex flex-col gap-0.5">
          <dt class="text-xs text-n-slate-11">
            {{ $t('BOT_INSIGHTS.NOW.PENDING') }}
          </dt>
          <dd class="m-0 text-xl font-medium tabular-nums text-n-slate-12">
            {{ formatCount(insight.current.pending_conversations) }}
          </dd>
        </div>
        <div class="flex flex-col gap-0.5">
          <dt class="text-xs text-n-slate-11">
            {{ $t('BOT_INSIGHTS.NOW.UNASSIGNED') }}
          </dt>
          <dd
            class="m-0 text-xl font-medium tabular-nums"
            :class="
              insight.current.unassigned_conversations
                ? 'text-n-amber-11'
                : 'text-n-slate-12'
            "
          >
            {{ formatCount(insight.current.unassigned_conversations) }}
          </dd>
        </div>
      </dl>
    </section>

    <TabBar
      :tabs="tabs"
      :initial-active-tab="activeTab"
      @tab-changed="selectTab"
    />

    <template v-if="activeTab === 0">
      <BotOutcomePanel :summary="summary" />
      <MetricStrip :items="summaryMetrics" />
      <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <InsightPanel
          :title="$t('BOT_INSIGHTS.CHARTS.CONVERSATIONS_PER_DAY')"
          :description="$t('BOT_INSIGHTS.CHARTS.CONVERSATIONS_PER_DAY_DESC')"
        >
          <template v-if="hasAny('conversations_count')">
            <ChartLegend :series="conversationsChart.series" />
            <BarChart
              :data="conversationsChart"
              :height="240"
              :max-bar-width="14"
              :bar-gap="2"
              :show-values="false"
              :aria-label="$t('BOT_INSIGHTS.CHARTS.CONVERSATIONS_PER_DAY')"
              :class="BAR_CHART_CLASS"
            />
          </template>
          <p
            v-else
            class="grid h-60 text-sm place-content-center text-n-slate-11"
          >
            {{ $t('BOT_INSIGHTS.EMPTY_CHART') }}
          </p>
        </InsightPanel>
        <InsightPanel
          :title="$t('BOT_INSIGHTS.CHARTS.MESSAGES_PER_DAY')"
          :description="$t('BOT_INSIGHTS.CHARTS.MESSAGES_PER_DAY_DESC')"
        >
          <LineChart
            v-if="hasAny('outgoing_messages_count')"
            :data="messagesChart"
            :height="260"
            :point-radius="3"
            :show-values="showValues"
            :aria-label="$t('BOT_INSIGHTS.CHARTS.MESSAGES_PER_DAY')"
            :class="LINE_CHART_CLASS"
          />
          <p
            v-else
            class="grid h-60 text-sm place-content-center text-n-slate-11"
          >
            {{ $t('BOT_INSIGHTS.EMPTY_CHART') }}
          </p>
        </InsightPanel>
      </div>
    </template>

    <template v-else-if="activeTab === 1">
      <MetricStrip
        :items="scheduleMetrics"
        columns="grid-cols-1 sm:grid-cols-3"
      />
      <InsightPanel
        :title="$t('BOT_INSIGHTS.CHARTS.WHEN_WRITE')"
        :description="$t('BOT_INSIGHTS.CHARTS.WHEN_WRITE_DESC')"
      >
        <div v-if="hasHeatmap" class="overflow-x-auto">
          <HeatmapChart
            class="min-w-[44rem]"
            :data="heatmapData"
            :colors="HEATMAP_COLORS"
            :quantiles="HEATMAP_QUANTILES"
            :cell-min-width="22"
            :cell-height="26"
            :gap="4"
            :row-label-width="64"
            zero-color="rgb(var(--solid-2))"
            :aria-label="$t('BOT_INSIGHTS.CHARTS.WHEN_WRITE')"
            :class="HEATMAP_CLASS"
          />
        </div>
        <p v-else class="py-10 text-sm text-center text-n-slate-11">
          {{ $t('BOT_INSIGHTS.EMPTY_CHART') }}
        </p>
      </InsightPanel>
      <InsightPanel
        :title="$t('BOT_INSIGHTS.CHARTS.BY_HOUR')"
        :description="$t('BOT_INSIGHTS.CHARTS.BY_HOUR_DESC')"
      >
        <BarChart
          v-if="hasHeatmap"
          :data="byHourChart"
          :height="220"
          :max-bar-width="20"
          :bar-gap="3"
          :aria-label="$t('BOT_INSIGHTS.CHARTS.BY_HOUR')"
          :class="BAR_CHART_CLASS"
        />
        <p
          v-else
          class="grid h-48 text-sm place-content-center text-n-slate-11"
        >
          {{ $t('BOT_INSIGHTS.EMPTY_CHART') }}
        </p>
      </InsightPanel>
    </template>

    <template v-else>
      <MetricStrip
        :items="qualityMetrics"
        columns="grid-cols-2 md:grid-cols-3"
      />
      <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <InsightPanel
          :title="$t('BOT_INSIGHTS.CHARTS.CSAT')"
          :description="
            csat.satisfaction_rate !== null &&
            csat.satisfaction_rate !== undefined
              ? $t('BOT_INSIGHTS.CHARTS.CSAT_DESC', {
                  rate: csat.satisfaction_rate,
                })
              : $t('BOT_INSIGHTS.CHARTS.CSAT_EMPTY_DESC')
          "
        >
          <DonutChart
            v-if="csatTotal"
            :data="csatChart"
            :diameter="176"
            :thickness="22"
            :aria-label="$t('BOT_INSIGHTS.CHARTS.CSAT')"
            :class="DONUT_CHART_CLASS"
          >
            <template #center>
              <div class="flex flex-col items-center leading-tight">
                <span class="text-2xl font-medium tabular-nums text-n-slate-12">
                  {{ csatCenter ? csatCenter.toFixed(1) : '--' }}
                </span>
                <span class="text-xs text-n-slate-11">{{ '/ 5' }}</span>
              </div>
            </template>
          </DonutChart>
          <p v-else class="py-10 text-sm text-center text-n-slate-11">
            {{ $t('BOT_INSIGHTS.NO_CSAT') }}
          </p>
        </InsightPanel>
        <InsightPanel
          v-for="list in lists"
          :key="list.key"
          :title="$t(`BOT_INSIGHTS.CHARTS.${list.key}`)"
          :description="$t(`BOT_INSIGHTS.CHARTS.${list.key}_DESC`)"
        >
          <ul
            v-if="list.items.length"
            class="flex flex-col gap-3 p-0 m-0 list-none"
          >
            <li v-for="item in list.items" :key="item.label">
              <div class="flex items-center justify-between gap-2 mb-1 text-sm">
                <span class="inline-flex items-center min-w-0 gap-1.5">
                  <Icon :icon="list.icon" class="size-3.5 text-n-slate-10" />
                  <span class="truncate text-n-slate-12">{{ item.label }}</span>
                </span>
                <span class="tabular-nums text-n-slate-11">
                  {{ formatCount(item.count) }}
                </span>
              </div>
              <div class="h-1.5 rounded-full bg-n-alpha-2">
                <div
                  class="h-full rounded-full"
                  :class="list.bar"
                  :style="{ width: `${item.width}%` }"
                />
              </div>
            </li>
          </ul>
          <p v-else class="py-10 text-sm text-center text-n-slate-11">
            {{ $t('BOT_INSIGHTS.EMPTY_CHART') }}
          </p>
        </InsightPanel>
      </div>
    </template>
  </div>
</template>
