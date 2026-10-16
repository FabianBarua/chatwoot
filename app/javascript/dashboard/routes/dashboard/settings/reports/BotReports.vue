<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import subDays from 'date-fns/subDays';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import { useAlert } from 'dashboard/composables';
import ReportsAPI from 'dashboard/api/reports';
import {
  generateReportURLParams,
  parseReportURLParams,
} from './helpers/reportFilterHelper';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';

import ReportHeader from './components/ReportHeader.vue';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import BotDetail from './components/botInsights/BotDetail.vue';

// Xplus: the bot report, with the same structure as the agent dashboard (AgentInsightsReports)
const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const insight = ref(null);
const isLoading = ref(false);

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
    const { data } = await ReportsAPI.getBotInsights(range.value);
    if (current === requestId) insight.value = data;
  } catch (error) {
    useAlert(t('REPORT.DATA_FETCHING_FAILED'));
  } finally {
    if (current === requestId) isLoading.value = false;
  }
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  // Keep the tab the supervisor was looking at
  router.replace({ query: { ...dateQuery(), tab: route.query.tab } });
  fetchReport();
};

onMounted(() => {
  const urlParams = parseReportURLParams(route.query);
  if (urlParams.range) selectedDateRange.value = urlParams.range;
  if (urlParams.from && urlParams.to) {
    customDateRange.value = [
      new Date(urlParams.from * 1000),
      new Date(urlParams.to * 1000),
    ];
  }
  fetchReport();
});
</script>

<template>
  <ReportHeader
    :header-title="$t('BOT_INSIGHTS.HEADER')"
    :header-description="$t('BOT_INSIGHTS.DESCRIPTION')"
  />

  <div class="flex flex-col gap-3 mb-5 md:flex-row md:items-center">
    <WootDatePicker
      v-model:date-range="customDateRange"
      v-model:range-type="selectedDateRange"
      @date-range-changed="onDateRangeChange"
    />
  </div>

  <BotDetail :insight="insight" :is-loading="isLoading" />
</template>
