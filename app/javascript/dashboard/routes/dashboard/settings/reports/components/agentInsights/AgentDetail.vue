<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { BarChart, DonutChart, HeatmapChart, LineChart } from '@chatwoot/viz';
import { CSAT_RATINGS } from 'shared/constants/messages';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import InsightPanel from './InsightPanel.vue';
import MetricStrip from './MetricStrip.vue';
import WorkloadPanel from './WorkloadPanel.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import PresenceTimeline from './PresenceTimeline.vue';
import ChartLegend from './ChartLegend.vue';
import {
  BAR_CHART_CLASS,
  COLORS,
  DONUT_CHART_CLASS,
  HEATMAP_CLASS,
  HEATMAP_COLORS,
  HEATMAP_QUANTILES,
  LINE_CHART_CLASS,
  STATUS_DOT_CLASSES,
  formatCount,
  formatDuration,
  formatHours,
  formatShortDuration,
  toHours,
} from './chartTheme';

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
    label: t(`AGENT_INSIGHTS.TABS.${key.toUpperCase()}`),
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

const TIMELINE_DAYS = 14;
const WEEKDAYS = [1, 2, 3, 4, 5, 6, 0];

const agent = computed(() => props.insight?.agent || {});
const summary = computed(() => props.insight?.summary || {});
const previous = computed(() => props.insight?.previous_summary || {});
const daily = computed(() => props.insight?.daily || []);

const resolutionRate = source =>
  source.attended_conversations_count
    ? Math.min(
        Math.round(
          (source.resolved_conversations_count /
            source.attended_conversations_count) *
            100
        ),
        100
      )
    : null;

const presenceSeconds = source =>
  (source.online_seconds || 0) + (source.busy_seconds || 0);

const metricItem = (key, format, options = {}) => {
  const now = options.value ? options.value(summary.value) : summary.value[key];
  const before = options.value
    ? options.value(previous.value)
    : previous.value[key];
  return {
    key,
    label: t(`AGENT_INSIGHTS.METRICS.${key}`),
    value: format(now),
    current: now,
    previous: before,
    lowerIsBetter: !!options.lowerIsBetter,
  };
};

const summaryMetrics = computed(() => [
  metricItem('attended_conversations_count', formatCount),
  metricItem('resolved_conversations_count', formatCount),
  metricItem(
    'resolution_rate',
    value => (value === null ? '--' : `${value}%`),
    { value: resolutionRate }
  ),
  metricItem('outgoing_messages_count', formatCount),
  metricItem('avg_first_response_time', formatDuration, {
    lowerIsBetter: true,
  }),
  metricItem('avg_reply_time', formatDuration, { lowerIsBetter: true }),
  metricItem('avg_resolution_time', formatDuration, { lowerIsBetter: true }),
  metricItem('private_notes_count', formatCount),
]);

const activeDays = computed(
  () => daily.value.filter(day => day.online_seconds || day.busy_seconds).length
);

const scheduleMetrics = computed(() => [
  metricItem('presence_seconds', value => formatHours(toHours(value)), {
    value: presenceSeconds,
  }),
  metricItem('sessions_count', formatCount),
  {
    key: 'avg_hours_per_day',
    label: t('AGENT_INSIGHTS.METRICS.avg_hours_per_day'),
    value: activeDays.value
      ? formatHours(toHours(presenceSeconds(summary.value) / activeDays.value))
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
    label: t('AGENT_INSIGHTS.METRICS.satisfaction_rate'),
    value: Number.isFinite(props.insight?.csat?.satisfaction_rate)
      ? `${props.insight.csat.satisfaction_rate}%`
      : '--',
  },
  metricItem('avg_first_response_time', formatDuration, {
    lowerIsBetter: true,
  }),
]);

const dayLabel = date =>
  new Intl.DateTimeFormat(intlLocale.value, {
    day: '2-digit',
    month: '2-digit',
  }).format(new Date(`${date}T00:00:00`));

const categories = computed(() => daily.value.map(day => dayLabel(day.date)));
const showValues = computed(() => daily.value.length <= 14);

const conversationsChart = computed(() => ({
  categories: categories.value,
  series: [
    {
      id: 'assigned',
      label: t('AGENT_INSIGHTS.SERIES.ASSIGNED'),
      color: COLORS.muted,
      data: daily.value.map(day => day.assigned_conversations_count),
    },
    {
      id: 'attended',
      label: t('AGENT_INSIGHTS.SERIES.ATTENDED'),
      color: COLORS.primary,
      data: daily.value.map(day => day.attended_conversations_count),
    },
    {
      id: 'resolved',
      label: t('AGENT_INSIGHTS.SERIES.RESOLVED'),
      color: COLORS.online,
      data: daily.value.map(day => day.resolved_conversations_count),
    },
  ],
}));

const presenceChart = computed(() => ({
  categories: categories.value,
  series: [
    {
      id: 'online',
      label: t('AGENT_ACTIVITY_REPORTS.STATUS.online'),
      color: COLORS.online,
      data: daily.value.map(day => toHours(day.online_seconds)),
    },
    {
      id: 'busy',
      label: t('AGENT_ACTIVITY_REPORTS.STATUS.busy'),
      color: COLORS.busy,
      data: daily.value.map(day => toHours(day.busy_seconds)),
    },
  ],
}));

const messagesChart = computed(() => ({
  categories: categories.value,
  series: [
    {
      id: 'messages',
      label: t('AGENT_INSIGHTS.SERIES.MESSAGES'),
      color: COLORS.secondary,
      pointBorderColor: 'rgb(var(--solid-2))',
      data: daily.value.map(day => day.outgoing_messages_count),
    },
  ],
}));

const firstResponseChart = computed(() => ({
  categories: categories.value,
  series: [
    {
      id: 'first_response',
      label: t('AGENT_INSIGHTS.SERIES.FIRST_RESPONSE'),
      color: COLORS.busy,
      pointBorderColor: 'rgb(var(--solid-2))',
      data: daily.value.map(day =>
        Number.isFinite(day.avg_first_response_time)
          ? Math.round((day.avg_first_response_time / 60) * 10) / 10
          : undefined
      ),
    },
  ],
}));

const formatMinutes = value => formatShortDuration(value * 60);

const hasAny = (key, ...more) =>
  daily.value.some(day => [key, ...more].some(k => day[k]));

const heatmapData = computed(() => {
  const cells = new Map(
    (props.insight?.hourly || []).map(cell => [
      `${cell.weekday}-${cell.hour}`,
      cell.count,
    ])
  );
  const columns = Array.from({ length: 24 }, (_, hour) => ({
    id: hour,
    label: `${String(hour).padStart(2, '0')}h`,
  }));
  return {
    columns,
    rows: WEEKDAYS.map(weekday => ({
      id: weekday,
      // 2023-01-01 was a Sunday, so day N of that week is weekday N
      label: new Intl.DateTimeFormat(intlLocale.value, {
        weekday: 'short',
      }).format(new Date(2023, 0, 1 + weekday)),
      data: columns.map(({ id }) => {
        const value = cells.get(`${weekday}-${id}`);
        return value ? { value } : null;
      }),
    })),
  };
});

const hasConversationsPerDay = computed(() =>
  hasAny('assigned_conversations_count', 'attended_conversations_count')
);

const hasHeatmap = computed(() => (props.insight?.hourly || []).length > 0);

const timelineRows = computed(() =>
  daily.value
    .slice(-TIMELINE_DAYS)
    .reverse()
    .map(day => {
      const start = new Date(`${day.date}T00:00:00`).getTime() / 1000;
      return {
        id: day.date,
        label: new Intl.DateTimeFormat(intlLocale.value, {
          weekday: 'short',
          day: '2-digit',
          month: '2-digit',
        }).format(new Date(`${day.date}T00:00:00`)),
        sublabel: formatHours(toHours(presenceSeconds(day))),
        start,
        end: start + 86400,
        segments: props.insight?.timeline || [],
      };
    })
);

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
const labels = computed(() => barList(props.insight?.labels || []));
const inboxes = computed(() => barList(props.insight?.inboxes || []));
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
      <Avatar
        :src="agent.thumbnail"
        :name="agent.name"
        :size="56"
        rounded-full
      />
      <div class="flex flex-col flex-1 min-w-0 gap-1">
        <div class="flex flex-wrap items-center gap-2">
          <h2 class="m-0 text-lg font-medium text-n-slate-12">
            {{ agent.name }}
          </h2>
          <span
            class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
          >
            {{ $t(`AGENT_INSIGHTS.ROLES.${agent.role}`) }}
          </span>
          <span
            class="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-12"
          >
            <span
              class="rounded-full size-2"
              :class="
                STATUS_DOT_CLASSES[agent.availability_status] ||
                STATUS_DOT_CLASSES.offline
              "
            />
            {{
              $t(
                `AGENT_ACTIVITY_REPORTS.STATUS.${agent.availability_status || 'offline'}`
              )
            }}
          </span>
        </div>
        <span class="text-sm text-n-slate-11">{{ agent.email }}</span>
      </div>
      <dl class="flex gap-6 m-0">
        <div class="flex flex-col gap-0.5">
          <dt class="text-xs text-n-slate-11">
            {{ $t('AGENT_INSIGHTS.NOW.OPEN') }}
          </dt>
          <dd class="m-0 text-xl font-medium tabular-nums text-n-slate-12">
            {{ formatCount(insight.current.open_conversations) }}
          </dd>
        </div>
        <div class="flex flex-col gap-0.5">
          <dt class="text-xs text-n-slate-11">
            {{ $t('AGENT_INSIGHTS.NOW.UNATTENDED') }}
          </dt>
          <dd
            class="m-0 text-xl font-medium tabular-nums"
            :class="
              insight.current.unattended_conversations
                ? 'text-n-amber-11'
                : 'text-n-slate-12'
            "
          >
            {{ formatCount(insight.current.unattended_conversations) }}
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
      <WorkloadPanel :workload="insight.workload" />
      <MetricStrip :items="summaryMetrics" />
      <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <InsightPanel
          :title="$t('AGENT_INSIGHTS.CHARTS.CONVERSATIONS_PER_DAY')"
          :description="$t('AGENT_INSIGHTS.CHARTS.CONVERSATIONS_PER_DAY_DESC')"
        >
          <template v-if="hasConversationsPerDay">
            <ChartLegend :series="conversationsChart.series" />
            <BarChart
              :data="conversationsChart"
              :height="240"
              :max-bar-width="16"
              :bar-gap="2"
              :aria-label="$t('AGENT_INSIGHTS.CHARTS.CONVERSATIONS_PER_DAY')"
              :class="BAR_CHART_CLASS"
            />
          </template>
          <p
            v-else
            class="grid h-60 text-sm place-content-center text-n-slate-11"
          >
            {{ $t('AGENT_INSIGHTS.EMPTY_CHART') }}
          </p>
        </InsightPanel>
        <InsightPanel
          :title="$t('AGENT_INSIGHTS.CHARTS.MESSAGES_PER_DAY')"
          :description="$t('AGENT_INSIGHTS.CHARTS.MESSAGES_PER_DAY_DESC')"
        >
          <LineChart
            v-if="hasAny('outgoing_messages_count')"
            :data="messagesChart"
            :height="260"
            :point-radius="3"
            :show-values="showValues"
            :aria-label="$t('AGENT_INSIGHTS.CHARTS.MESSAGES_PER_DAY')"
            :class="LINE_CHART_CLASS"
          />
          <p
            v-else
            class="grid h-60 text-sm place-content-center text-n-slate-11"
          >
            {{ $t('AGENT_INSIGHTS.EMPTY_CHART') }}
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
        :title="$t('AGENT_INSIGHTS.CHARTS.HOURS_PER_DAY')"
        :description="$t('AGENT_INSIGHTS.CHARTS.HOURS_PER_DAY_DESC')"
      >
        <template v-if="hasAny('online_seconds', 'busy_seconds')">
          <ChartLegend :series="presenceChart.series" />
          <BarChart
            :data="presenceChart"
            stacked
            :height="240"
            :max-bar-width="28"
            :format-value="formatHours"
            :aria-label="$t('AGENT_INSIGHTS.CHARTS.HOURS_PER_DAY')"
            :class="BAR_CHART_CLASS"
          />
        </template>
        <p
          v-else
          class="grid h-60 text-sm place-content-center text-n-slate-11"
        >
          {{ $t('AGENT_INSIGHTS.EMPTY_CHART') }}
        </p>
      </InsightPanel>
      <InsightPanel
        :title="$t('AGENT_INSIGHTS.CHARTS.WHEN_WORKS')"
        :description="$t('AGENT_INSIGHTS.CHARTS.WHEN_WORKS_DESC')"
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
            :aria-label="$t('AGENT_INSIGHTS.CHARTS.WHEN_WORKS')"
            :class="HEATMAP_CLASS"
          />
        </div>
        <p v-else class="py-10 text-sm text-center text-n-slate-11">
          {{ $t('AGENT_INSIGHTS.EMPTY_CHART') }}
        </p>
      </InsightPanel>
      <InsightPanel
        :title="$t('AGENT_INSIGHTS.CHARTS.PRESENCE_TIMELINE')"
        :description="
          $t('AGENT_INSIGHTS.CHARTS.PRESENCE_TIMELINE_DESC', {
            days: TIMELINE_DAYS,
          })
        "
      >
        <PresenceTimeline :rows="timelineRows" label-width="7rem" />
      </InsightPanel>
    </template>

    <template v-else>
      <MetricStrip :items="qualityMetrics" />
      <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <InsightPanel
          :title="$t('AGENT_INSIGHTS.CHARTS.CSAT')"
          :description="
            csat.satisfaction_rate !== null &&
            csat.satisfaction_rate !== undefined
              ? $t('AGENT_INSIGHTS.CHARTS.CSAT_DESC', {
                  rate: csat.satisfaction_rate,
                })
              : ''
          "
        >
          <DonutChart
            v-if="csatTotal"
            :data="csatChart"
            :diameter="176"
            :thickness="22"
            :aria-label="$t('AGENT_INSIGHTS.CHARTS.CSAT')"
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
            {{ $t('AGENT_INSIGHTS.NO_CSAT') }}
          </p>
        </InsightPanel>
        <InsightPanel
          :title="$t('AGENT_INSIGHTS.CHARTS.FIRST_RESPONSE_PER_DAY')"
          :description="$t('AGENT_INSIGHTS.CHARTS.FIRST_RESPONSE_PER_DAY_DESC')"
        >
          <LineChart
            v-if="hasAny('avg_first_response_time')"
            :data="firstResponseChart"
            :height="240"
            :point-radius="3"
            :show-values="false"
            :format-value="formatMinutes"
            :aria-label="$t('AGENT_INSIGHTS.CHARTS.FIRST_RESPONSE_PER_DAY')"
            :class="LINE_CHART_CLASS"
          />
          <p
            v-else
            class="grid h-60 text-sm place-content-center text-n-slate-11"
          >
            {{ $t('AGENT_INSIGHTS.EMPTY_CHART') }}
          </p>
        </InsightPanel>
      </div>
      <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <InsightPanel
          v-for="list in [
            { key: 'LABELS', items: labels, icon: 'i-lucide-tag' },
            { key: 'INBOXES', items: inboxes, icon: 'i-lucide-inbox' },
          ]"
          :key="list.key"
          :title="$t(`AGENT_INSIGHTS.CHARTS.${list.key}`)"
          :description="$t(`AGENT_INSIGHTS.CHARTS.${list.key}_DESC`)"
        >
          <ul
            v-if="list.items.length"
            class="flex flex-col gap-3 p-0 m-0 list-none"
          >
            <li v-for="item in list.items" :key="item.label || item.id">
              <div class="flex items-center justify-between gap-2 mb-1 text-sm">
                <span class="inline-flex items-center min-w-0 gap-1.5">
                  <Icon :icon="list.icon" class="size-3.5 text-n-slate-10" />
                  <span class="truncate text-n-slate-12">
                    {{ item.label || item.name }}
                  </span>
                </span>
                <span class="tabular-nums text-n-slate-11">
                  {{ formatCount(item.count) }}
                </span>
              </div>
              <div class="h-1.5 rounded-full bg-n-alpha-2">
                <div
                  class="h-full rounded-full bg-n-blue-9"
                  :style="{ width: `${item.width}%` }"
                />
              </div>
            </li>
          </ul>
          <p v-else class="py-10 text-sm text-center text-n-slate-11">
            {{ $t('AGENT_INSIGHTS.EMPTY_CHART') }}
          </p>
        </InsightPanel>
      </div>
    </template>
  </div>
</template>
