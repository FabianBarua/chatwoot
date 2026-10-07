<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import subDays from 'date-fns/subDays';
import addDays from 'date-fns/addDays';
import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';
import differenceInCalendarDays from 'date-fns/differenceInCalendarDays';
import { BarChart, HeatmapChart } from '@chatwoot/viz';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ReportsAPI from 'dashboard/api/reports';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';
import {
  generateReportURLParams,
  parseReportURLParams,
} from './helpers/reportFilterHelper';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';

import ReportHeader from './components/ReportHeader.vue';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import ActivityTable from './components/agentInsights/ActivityTable.vue';
import AgentPicker from './components/agentInsights/AgentPicker.vue';
import ChartLegend from './components/agentInsights/ChartLegend.vue';
import InsightPanel from './components/agentInsights/InsightPanel.vue';
import MetricStrip from './components/agentInsights/MetricStrip.vue';
import PresenceTimeline from './components/agentInsights/PresenceTimeline.vue';
import { presenceCoverage } from './components/agentInsights/presenceCoverage';
import {
  BAR_CHART_CLASS,
  COLORS,
  COVERAGE_COLORS,
  HEATMAP_CLASS,
  HEATMAP_COLORS,
  HEATMAP_QUANTILES,
  STATUS_DOT_CLASSES,
  formatAgents,
  formatCount,
  formatHours,
  toHours,
} from './components/agentInsights/chartTheme';

const { t, locale } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const agents = useMapGetter('agents/getAgents');

const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const selectedAgentId = ref('');
const rows = ref([]);
const isLoading = ref(false);
const isDownloading = ref(false);
const selectedDay = ref('');

const from = computed(() => getUnixStartOfDay(customDateRange.value[0]));
const to = computed(() => getUnixEndOfDay(customDateRange.value[1]));
const intlLocale = computed(() => locale.value.replace('_', '-'));

const TAB_KEYS = ['overview', 'timeline', 'coverage', 'details'];
const tabs = computed(() =>
  TAB_KEYS.map(key => ({
    value: key,
    label: t(`AGENT_ACTIVITY_REPORTS.TABS.${key.toUpperCase()}`),
  }))
);
const activeTab = computed(() => {
  const index = TAB_KEYS.indexOf(route.query.tab);
  return index === -1 ? 0 : index;
});

const requestParams = () => ({
  since: from.value,
  until: to.value,
  userId: selectedAgentId.value || undefined,
});

const updateURLParams = (tab = route.query.tab) => {
  const params = generateReportURLParams({
    from: from.value,
    to: to.value,
    range: selectedDateRange.value,
  });
  router.replace({
    query: {
      ...params,
      agent: selectedAgentId.value || undefined,
      tab: tab && tab !== 'overview' ? tab : undefined,
    },
  });
};

const selectTab = tab => updateURLParams(tab.value);

const fetchReport = async () => {
  isLoading.value = true;
  updateURLParams();
  try {
    const { data } = await ReportsAPI.getAgentActivity(requestParams());
    rows.value = data;
  } catch (error) {
    useAlert(t('REPORT.DATA_FETCHING_FAILED'));
  } finally {
    isLoading.value = false;
  }
};

const selectAgent = id => {
  selectedAgentId.value = id ? String(id) : '';
  fetchReport();
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  fetchReport();
};

const downloadReport = async () => {
  isDownloading.value = true;
  try {
    const { data } = await ReportsAPI.getAgentActivityCSV(requestParams());
    downloadCsvFile(
      `agent-activity-${format(fromUnixTime(to.value), 'dd-MM-yyyy')}.csv`,
      data
    );
  } catch (error) {
    useAlert(t('REPORT.DATA_FETCHING_FAILED'));
  } finally {
    isDownloading.value = false;
  }
};

const sum = key => rows.value.reduce((total, row) => total + row[key], 0);

const metrics = computed(() => [
  {
    key: 'ONLINE',
    label: t('AGENT_ACTIVITY_REPORTS.TOTALS.ONLINE'),
    value: formatHours(toHours(sum('online_seconds'))),
  },
  {
    key: 'BUSY',
    label: t('AGENT_ACTIVITY_REPORTS.TOTALS.BUSY'),
    value: formatHours(toHours(sum('busy_seconds'))),
  },
  {
    key: 'SESSIONS',
    label: t('AGENT_ACTIVITY_REPORTS.TOTALS.SESSIONS'),
    value: formatCount(sum('sessions_count')),
  },
  {
    key: 'AGENTS_ONLINE',
    label: t('AGENT_ACTIVITY_REPORTS.TOTALS.AGENTS_ONLINE'),
    value: formatCount(
      rows.value.filter(row => row.current_status !== 'offline').length
    ),
  },
]);

const firstName = name => (name || '').split(' ')[0];

const activeRows = computed(() =>
  rows.value.filter(row => row.online_seconds || row.busy_seconds)
);

// "since 14:13" for today, "since 06/10 14:13" for older changes
// Only meaningful when the period reaches the present and the status changed inside it
const sinceLabel = row => {
  const last = row.timeline[row.timeline.length - 1];
  const reachesNow = to.value >= Date.now() / 1000;
  if (!reachesNow || !last || last.status !== row.current_status) return '';
  if (last.from <= from.value) return '';
  const changedAt = fromUnixTime(last.from);
  const sameDay =
    format(changedAt, 'yyyy-MM-dd') === format(new Date(), 'yyyy-MM-dd');
  return t('AGENT_ACTIVITY_REPORTS.NOW.SINCE', {
    time: format(changedAt, sameDay ? 'HH:mm' : 'dd/MM HH:mm'),
  });
};

// Agents sorted so those connected now come first
const statusRows = computed(() => {
  const rank = { online: 0, busy: 1, offline: 2 };
  return [...rows.value].sort(
    (a, b) =>
      (rank[a.current_status] ?? 2) - (rank[b.current_status] ?? 2) ||
      a.name.localeCompare(b.name)
  );
});

const hoursChart = computed(() => {
  const sorted = [...activeRows.value].sort(
    (a, b) =>
      b.online_seconds + b.busy_seconds - (a.online_seconds + a.busy_seconds)
  );
  return {
    categories: sorted.map(row => firstName(row.name)),
    series: [
      {
        id: 'online',
        label: t('AGENT_ACTIVITY_REPORTS.STATUS.online'),
        color: COLORS.online,
        data: sorted.map(row => toHours(row.online_seconds)),
      },
      {
        id: 'busy',
        label: t('AGENT_ACTIVITY_REPORTS.STATUS.busy'),
        color: COLORS.busy,
        data: sorted.map(row => toHours(row.busy_seconds)),
      },
    ],
  };
});

// Days of the selected range, oldest first, never past today
const rangeDays = computed(() => {
  const start = customDateRange.value[0];
  const end = new Date(
    Math.min(customDateRange.value[1].getTime(), Date.now())
  );
  const total = Math.max(differenceInCalendarDays(end, start), 0);
  return Array.from({ length: total + 1 }, (_, index) =>
    format(addDays(start, index), 'yyyy-MM-dd')
  );
});

const dayHeatmap = computed(() => {
  const columns = rangeDays.value.map(date => ({
    id: date,
    label: format(new Date(`${date}T00:00:00`), 'dd/MM'),
  }));
  return {
    columns,
    rows: activeRows.value.map(row => {
      const byDate = Object.fromEntries(
        row.daily.map(day => [day.date, day.online_seconds + day.busy_seconds])
      );
      return {
        id: row.id,
        label: row.name,
        data: columns.map(({ id }) =>
          byDate[id] ? { value: toHours(byDate[id]) } : null
        ),
      };
    }),
  };
});

const coverage = computed(() =>
  presenceCoverage(rows.value, rangeDays.value.length)
);

const coverageChart = computed(() => ({
  categories: coverage.value.byHour.map((_, hour) =>
    String(hour).padStart(2, '0')
  ),
  series: [
    {
      id: 'coverage',
      label: t('AGENT_ACTIVITY_REPORTS.COVERAGE.SERIES'),
      color: COLORS.online,
      data: coverage.value.byHour,
    },
  ],
}));

const hasCoverage = computed(() => coverage.value.byHour.some(Boolean));

const coverageHeatmap = computed(() => {
  const columns = Array.from({ length: 24 }, (_, hour) => ({
    id: hour,
    label: String(hour).padStart(2, '0'),
  }));
  // Monday first; 2023-01-01 was a Sunday
  return {
    columns,
    rows: [1, 2, 3, 4, 5, 6, 0].map(weekday => ({
      id: weekday,
      label: new Intl.DateTimeFormat(intlLocale.value, {
        weekday: 'short',
      }).format(new Date(2023, 0, 1 + weekday)),
      data: columns.map(({ id }) => {
        const value = coverage.value.byWeekdayHour[weekday][id];
        return value ? { value } : null;
      }),
    })),
  };
});

const timelineDay = computed(() =>
  rangeDays.value.includes(selectedDay.value)
    ? selectedDay.value
    : rangeDays.value[rangeDays.value.length - 1]
);
const dayIndex = computed(() => rangeDays.value.indexOf(timelineDay.value));
const moveDay = step => {
  selectedDay.value = rangeDays.value[dayIndex.value + step];
};

const timelineRows = computed(() => {
  if (!timelineDay.value) return [];
  const start = new Date(`${timelineDay.value}T00:00:00`).getTime() / 1000;
  return rows.value.map(row => {
    const day = row.daily.find(item => item.date === timelineDay.value);
    return {
      id: row.id,
      label: row.name,
      sublabel: formatHours(
        toHours((day?.online_seconds || 0) + (day?.busy_seconds || 0))
      ),
      start,
      end: start + 86400,
      segments: row.timeline,
    };
  });
});

const timelineDayLabel = computed(() =>
  timelineDay.value
    ? new Intl.DateTimeFormat(intlLocale.value, {
        weekday: 'long',
        day: '2-digit',
        month: 'long',
      }).format(new Date(`${timelineDay.value}T00:00:00`))
    : ''
);

onMounted(() => {
  const urlParams = parseReportURLParams(route.query);
  if (urlParams.range) selectedDateRange.value = urlParams.range;
  if (urlParams.from && urlParams.to) {
    customDateRange.value = [
      new Date(urlParams.from * 1000),
      new Date(urlParams.to * 1000),
    ];
  }
  if (route.query.agent) selectedAgentId.value = String(route.query.agent);

  store.dispatch('agents/get');
  fetchReport();
});
</script>

<template>
  <ReportHeader
    :header-title="$t('AGENT_ACTIVITY_REPORTS.HEADER')"
    :header-description="$t('AGENT_ACTIVITY_REPORTS.DESCRIPTION')"
  >
    <Button
      :label="$t('AGENT_ACTIVITY_REPORTS.DOWNLOAD')"
      icon="i-ph-download-simple"
      size="sm"
      :is-loading="isDownloading"
      @click="downloadReport"
    />
  </ReportHeader>

  <div
    class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"
  >
    <WootDatePicker
      v-model:date-range="customDateRange"
      v-model:range-type="selectedDateRange"
      @date-range-changed="onDateRangeChange"
    />
    <AgentPicker
      :agents="agents"
      :model-value="selectedAgentId"
      @update:model-value="selectAgent"
    />
  </div>

  <div class="flex flex-col gap-5 mt-5">
    <MetricStrip :items="metrics" :is-loading="isLoading && !rows.length" />

    <TabBar
      :tabs="tabs"
      :initial-active-tab="activeTab"
      @tab-changed="selectTab"
    />

    <p
      v-if="!isLoading && !rows.length"
      class="py-10 text-sm text-center rounded-xl text-n-slate-11 outline outline-1 outline-n-container bg-n-solid-2"
    >
      {{ $t('AGENT_ACTIVITY_REPORTS.NO_DATA') }}
    </p>

    <template v-else-if="activeTab === 0">
      <InsightPanel
        :title="$t('AGENT_ACTIVITY_REPORTS.NOW.TITLE')"
        :description="$t('AGENT_ACTIVITY_REPORTS.NOW.DESCRIPTION')"
      >
        <ul
          class="grid grid-cols-1 gap-2 p-0 m-0 list-none sm:grid-cols-2 xl:grid-cols-3"
        >
          <li
            v-for="row in statusRows"
            :key="row.id"
            class="flex items-center gap-3 px-3 py-2.5 rounded-lg bg-n-alpha-1"
          >
            <Avatar
              :src="row.thumbnail"
              :name="row.name"
              :size="32"
              rounded-full
            />
            <div class="flex flex-col flex-1 min-w-0">
              <span class="text-sm truncate text-n-slate-12">
                {{ row.name }}
              </span>
              <span
                class="inline-flex items-center gap-1.5 text-xs text-n-slate-11"
              >
                <span
                  class="rounded-full size-2"
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
                <span v-if="sinceLabel(row)" class="text-n-slate-10">
                  {{ sinceLabel(row) }}
                </span>
              </span>
            </div>
          </li>
        </ul>
      </InsightPanel>

      <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <InsightPanel
          :title="$t('AGENT_ACTIVITY_REPORTS.CHARTS.HOURS_BY_AGENT')"
          :description="$t('AGENT_ACTIVITY_REPORTS.CHARTS.HOURS_BY_AGENT_DESC')"
        >
          <template v-if="activeRows.length">
            <ChartLegend :series="hoursChart.series" />
            <BarChart
              :data="hoursChart"
              stacked
              :height="260"
              :max-bar-width="28"
              :format-value="formatHours"
              :aria-label="$t('AGENT_ACTIVITY_REPORTS.CHARTS.HOURS_BY_AGENT')"
              :class="BAR_CHART_CLASS"
            />
          </template>
          <p
            v-else
            class="grid text-sm h-64 place-content-center text-n-slate-11"
          >
            {{ $t('AGENT_ACTIVITY_REPORTS.NO_DATA') }}
          </p>
        </InsightPanel>
        <InsightPanel
          :title="$t('AGENT_ACTIVITY_REPORTS.CHARTS.HOURS_BY_DAY')"
          :description="$t('AGENT_ACTIVITY_REPORTS.CHARTS.HOURS_BY_DAY_DESC')"
        >
          <div v-if="activeRows.length" class="overflow-x-auto">
            <HeatmapChart
              :data="dayHeatmap"
              :colors="HEATMAP_COLORS"
              :quantiles="HEATMAP_QUANTILES"
              :cell-min-width="34"
              :cell-height="28"
              :gap="4"
              :row-label-width="96"
              :format-value="formatHours"
              zero-color="rgb(var(--solid-2))"
              :aria-label="$t('AGENT_ACTIVITY_REPORTS.CHARTS.HOURS_BY_DAY')"
              :class="HEATMAP_CLASS"
            />
          </div>
          <p
            v-else
            class="grid text-sm h-64 place-content-center text-n-slate-11"
          >
            {{ $t('AGENT_ACTIVITY_REPORTS.NO_DATA') }}
          </p>
        </InsightPanel>
      </div>
    </template>

    <InsightPanel
      v-else-if="activeTab === 1"
      :title="timelineDayLabel"
      :description="$t('AGENT_ACTIVITY_REPORTS.CHARTS.DAY_TIMELINE_DESC')"
    >
      <template #actions>
        <div class="flex items-center gap-1">
          <Button
            xs
            slate
            ghost
            icon="i-lucide-chevron-left"
            :disabled="dayIndex <= 0"
            :aria-label="$t('AGENT_ACTIVITY_REPORTS.CHARTS.PREVIOUS_DAY')"
            @click="moveDay(-1)"
          />
          <Button
            xs
            slate
            ghost
            icon="i-lucide-chevron-right"
            :disabled="dayIndex >= rangeDays.length - 1"
            :aria-label="$t('AGENT_ACTIVITY_REPORTS.CHARTS.NEXT_DAY')"
            @click="moveDay(1)"
          />
        </div>
      </template>
      <PresenceTimeline :rows="timelineRows" />
    </InsightPanel>

    <template v-else-if="activeTab === 2">
      <InsightPanel
        :title="$t('AGENT_ACTIVITY_REPORTS.COVERAGE.BY_HOUR')"
        :description="$t('AGENT_ACTIVITY_REPORTS.COVERAGE.BY_HOUR_DESC')"
      >
        <BarChart
          v-if="hasCoverage"
          :data="coverageChart"
          :height="240"
          :max-bar-width="22"
          :bar-gap="3"
          :format-value="formatAgents"
          :aria-label="$t('AGENT_ACTIVITY_REPORTS.COVERAGE.BY_HOUR')"
          :class="BAR_CHART_CLASS"
        />
        <p
          v-else
          class="grid text-sm h-60 place-content-center text-n-slate-11"
        >
          {{ $t('AGENT_ACTIVITY_REPORTS.NO_DATA') }}
        </p>
      </InsightPanel>
      <InsightPanel
        :title="$t('AGENT_ACTIVITY_REPORTS.COVERAGE.BY_WEEKDAY')"
        :description="$t('AGENT_ACTIVITY_REPORTS.COVERAGE.BY_WEEKDAY_DESC')"
      >
        <div v-if="hasCoverage" class="overflow-x-auto">
          <HeatmapChart
            class="min-w-[44rem]"
            :data="coverageHeatmap"
            :colors="COVERAGE_COLORS"
            :quantiles="HEATMAP_QUANTILES"
            :cell-min-width="22"
            :cell-height="26"
            :gap="4"
            :row-label-width="64"
            :format-value="formatAgents"
            zero-color="rgb(var(--solid-2))"
            :aria-label="$t('AGENT_ACTIVITY_REPORTS.COVERAGE.BY_WEEKDAY')"
            :class="HEATMAP_CLASS"
          />
        </div>
        <p
          v-else
          class="grid text-sm h-60 place-content-center text-n-slate-11"
        >
          {{ $t('AGENT_ACTIVITY_REPORTS.NO_DATA') }}
        </p>
      </InsightPanel>
    </template>

    <ActivityTable
      v-else
      :rows="rows"
      :is-loading="isLoading"
      :range-end="to"
    />
  </div>
</template>
