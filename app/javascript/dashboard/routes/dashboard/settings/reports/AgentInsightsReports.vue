<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import subDays from 'date-fns/subDays';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ReportsAPI from 'dashboard/api/reports';
import {
  generateReportURLParams,
  parseReportURLParams,
} from './helpers/reportFilterHelper';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';

import ReportHeader from './components/ReportHeader.vue';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import AgentPicker from './components/agentInsights/AgentPicker.vue';
import AgentsOverview from './components/agentInsights/AgentsOverview.vue';
import AgentDetail from './components/agentInsights/AgentDetail.vue';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const agents = useMapGetter('agents/getAgents');

const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const rows = ref([]);
const insight = ref(null);
const isLoading = ref(false);

const selectedAgentId = computed(() => route.params.id || '');

const range = computed(() => ({
  since: getUnixStartOfDay(customDateRange.value[0]),
  until: getUnixEndOfDay(customDateRange.value[1]),
}));

const dateQuery = () =>
  generateReportURLParams({
    from: range.value.since,
    to: range.value.until,
    range: selectedDateRange.value,
  });

let requestId = 0;
const fetchReport = async () => {
  requestId += 1;
  const current = requestId;
  isLoading.value = true;
  try {
    if (selectedAgentId.value) {
      const { data } = await ReportsAPI.getAgentInsight(
        selectedAgentId.value,
        range.value
      );
      if (current === requestId) insight.value = data;
    } else {
      const { data } = await ReportsAPI.getAgentInsights(range.value);
      if (current === requestId) rows.value = data;
    }
  } catch (error) {
    useAlert(t('REPORT.DATA_FETCHING_FAILED'));
  } finally {
    if (current === requestId) isLoading.value = false;
  }
};

const selectAgent = id => {
  router.push({
    name: id ? 'agent_reports_show' : 'agent_reports_index',
    params: id
      ? { ...route.params, id }
      : { accountId: route.params.accountId },
    // Keep the tab the supervisor was looking at when switching agents
    query: { ...dateQuery(), tab: id ? route.query.tab : undefined },
  });
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  router.replace({ query: dateQuery() });
  fetchReport();
};

watch(selectedAgentId, (id, previousId) => {
  if (id === previousId) return;
  insight.value = null;
  fetchReport();
});

onMounted(() => {
  const urlParams = parseReportURLParams(route.query);
  if (urlParams.range) selectedDateRange.value = urlParams.range;
  if (urlParams.from && urlParams.to) {
    customDateRange.value = [
      new Date(urlParams.from * 1000),
      new Date(urlParams.to * 1000),
    ];
  }
  store.dispatch('agents/get');
  fetchReport();
});
</script>

<template>
  <ReportHeader
    :header-title="$t('AGENT_INSIGHTS.HEADER')"
    :header-description="$t('AGENT_INSIGHTS.DESCRIPTION')"
  />

  <div
    class="flex flex-col gap-3 mb-5 md:flex-row md:items-center md:justify-between"
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

  <AgentDetail
    v-if="selectedAgentId"
    :insight="insight"
    :is-loading="isLoading"
  />
  <AgentsOverview
    v-else
    :rows="rows"
    :is-loading="isLoading"
    @select="selectAgent"
  />
</template>
