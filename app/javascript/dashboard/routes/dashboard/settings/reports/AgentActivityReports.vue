<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import subDays from 'date-fns/subDays';
import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';
import { formatTime } from '@chatwoot/utils';
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
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
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
const expandedIds = ref([]);

const from = computed(() => getUnixStartOfDay(customDateRange.value[0]));
const to = computed(() => getUnixEndOfDay(customDateRange.value[1]));

const requestParams = () => ({
  since: from.value,
  until: to.value,
  userId: selectedAgentId.value || undefined,
});

const STATUS_CLASSES = {
  online: 'bg-n-teal-9',
  busy: 'bg-n-amber-9',
  offline: 'bg-n-slate-9',
};

const statusLabel = status =>
  t(`AGENT_ACTIVITY_REPORTS.STATUS.${status || 'offline'}`);

const duration = seconds => (seconds ? formatTime(seconds) : '--');
const dateTime = unix =>
  unix ? format(fromUnixTime(unix), 'dd/MM HH:mm') : '--';
const count = value => (value ? value.toLocaleString() : '--');

const totals = computed(() => ({
  online: rows.value.reduce((sum, row) => sum + row.online_seconds, 0),
  busy: rows.value.reduce((sum, row) => sum + row.busy_seconds, 0),
  sessions: rows.value.reduce((sum, row) => sum + row.sessions_count, 0),
  agentsOnline: rows.value.filter(row => row.current_status !== 'offline')
    .length,
}));

const isExpanded = id => expandedIds.value.includes(id);
const toggleRow = id => {
  expandedIds.value = isExpanded(id)
    ? expandedIds.value.filter(item => item !== id)
    : [...expandedIds.value, id];
};

const segmentEnd = segment =>
  segment.to >= to.value
    ? t('AGENT_ACTIVITY_REPORTS.DETAIL.NOW')
    : dateTime(segment.to);

const updateURLParams = () => {
  const params = generateReportURLParams({
    from: from.value,
    to: to.value,
    range: selectedDateRange.value,
  });
  router.replace({
    query: { ...params, agent: selectedAgentId.value || undefined },
  });
};

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
    <select
      v-model="selectedAgentId"
      class="!mb-0 w-full md:w-64 text-sm"
      @change="fetchReport"
    >
      <option value="">{{ $t('AGENT_ACTIVITY_REPORTS.ALL_AGENTS') }}</option>
      <option v-for="agent in agents" :key="agent.id" :value="String(agent.id)">
        {{ agent.name }}
      </option>
    </select>
  </div>

  <div class="grid grid-cols-2 gap-3 mt-5 md:grid-cols-4">
    <div
      v-for="(value, key) in {
        ONLINE: duration(totals.online),
        BUSY: duration(totals.busy),
        SESSIONS: totals.sessions,
        AGENTS_ONLINE: totals.agentsOnline,
      }"
      :key="key"
      class="flex flex-col gap-1 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
    >
      <span class="text-xs text-n-slate-11">
        {{ $t(`AGENT_ACTIVITY_REPORTS.TOTALS.${key}`) }}
      </span>
      <span class="text-xl font-medium text-n-slate-12">{{ value }}</span>
    </div>
  </div>

  <div
    class="mt-5 overflow-x-auto rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
  >
    <div
      v-if="isLoading"
      class="flex items-center justify-center gap-2 py-10 text-sm text-n-slate-11"
    >
      <Spinner />
      {{ $t('AGENT_ACTIVITY_REPORTS.LOADING') }}
    </div>
    <p
      v-else-if="!rows.length"
      class="py-10 text-sm text-center text-n-slate-11"
    >
      {{ $t('AGENT_ACTIVITY_REPORTS.NO_DATA') }}
    </p>
    <table v-else class="w-full text-sm text-left whitespace-nowrap">
      <thead class="text-xs text-n-slate-11 bg-n-slate-2">
        <tr>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.AGENT') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.CURRENT_STATUS') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.ONLINE_TIME') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.BUSY_TIME') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.SESSIONS') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.FIRST_ONLINE') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.LAST_OFFLINE') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.CONVERSATIONS') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.RESOLVED') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.AVG_FIRST_RESPONSE') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.AVG_REPLY_TIME') }}
          </th>
          <th class="px-4 py-3 font-medium">
            {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.MESSAGES_SENT') }}
          </th>
        </tr>
      </thead>
      <tbody>
        <template v-for="row in rows" :key="row.id">
          <tr
            class="border-t cursor-pointer border-n-weak hover:bg-n-alpha-1"
            @click="toggleRow(row.id)"
          >
            <td class="px-4 py-2">
              <div class="flex items-center gap-2">
                <Icon
                  :icon="
                    isExpanded(row.id)
                      ? 'i-lucide-chevron-down'
                      : 'i-lucide-chevron-right'
                  "
                  class="size-4 text-n-slate-10"
                />
                <Avatar
                  :src="row.thumbnail"
                  :name="row.name"
                  :status="row.current_status"
                  :size="28"
                  rounded-full
                />
                <div class="flex flex-col min-w-0">
                  <span class="font-medium text-n-slate-12">{{
                    row.name
                  }}</span>
                  <span class="text-xs text-n-slate-11">{{ row.email }}</span>
                </div>
              </div>
            </td>
            <td class="px-4 py-2">
              <span class="inline-flex items-center gap-1.5">
                <span
                  class="size-2 rounded-full"
                  :class="
                    STATUS_CLASSES[row.current_status] || STATUS_CLASSES.offline
                  "
                />
                {{ statusLabel(row.current_status) }}
              </span>
            </td>
            <td class="px-4 py-2 text-n-slate-12">
              {{ duration(row.online_seconds) }}
            </td>
            <td class="px-4 py-2 text-n-slate-12">
              {{ duration(row.busy_seconds) }}
            </td>
            <td class="px-4 py-2 text-n-slate-12">
              {{ count(row.sessions_count) }}
            </td>
            <td class="px-4 py-2 text-n-slate-12">
              {{ dateTime(row.first_online_at) }}
            </td>
            <td class="px-4 py-2 text-n-slate-12">
              {{ dateTime(row.last_offline_at) }}
            </td>
            <td class="px-4 py-2 text-n-slate-12">
              {{ count(row.conversations_count) }}
            </td>
            <td class="px-4 py-2 text-n-slate-12">
              {{ count(row.resolved_conversations_count) }}
            </td>
            <td class="px-4 py-2 text-n-slate-12">
              {{ duration(row.avg_first_response_time) }}
            </td>
            <td class="px-4 py-2 text-n-slate-12">
              {{ duration(row.avg_reply_time) }}
            </td>
            <td class="px-4 py-2 text-n-slate-12">
              {{ count(row.outgoing_messages_count) }}
            </td>
          </tr>
          <tr
            v-if="isExpanded(row.id)"
            class="border-t border-n-weak bg-n-slate-1"
          >
            <td colspan="12" class="px-4 py-3">
              <div class="grid grid-cols-1 gap-4 lg:grid-cols-3">
                <div class="lg:col-span-2">
                  <h4
                    class="mb-2 text-xs font-medium uppercase text-n-slate-11"
                  >
                    {{ $t('AGENT_ACTIVITY_REPORTS.DETAIL.TIMELINE') }}
                  </h4>
                  <p
                    v-if="!row.timeline.length"
                    class="text-xs text-n-slate-11"
                  >
                    {{ $t('AGENT_ACTIVITY_REPORTS.DETAIL.EMPTY') }}
                  </p>
                  <div v-else class="overflow-y-auto max-h-80">
                    <table class="w-full text-xs">
                      <thead class="text-n-slate-11">
                        <tr>
                          <th class="py-1 pr-4 font-medium text-left">
                            {{ $t('AGENT_ACTIVITY_REPORTS.DETAIL.STATUS') }}
                          </th>
                          <th class="py-1 pr-4 font-medium text-left">
                            {{ $t('AGENT_ACTIVITY_REPORTS.DETAIL.FROM') }}
                          </th>
                          <th class="py-1 pr-4 font-medium text-left">
                            {{ $t('AGENT_ACTIVITY_REPORTS.DETAIL.TO') }}
                          </th>
                          <th class="py-1 pr-4 font-medium text-left">
                            {{ $t('AGENT_ACTIVITY_REPORTS.DETAIL.DURATION') }}
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr
                          v-for="segment in row.timeline"
                          :key="segment.from"
                          class="border-t border-n-weak"
                        >
                          <td class="py-1 pr-4">
                            <span class="inline-flex items-center gap-1.5">
                              <span
                                class="size-2 rounded-full"
                                :class="STATUS_CLASSES[segment.status]"
                              />
                              {{ statusLabel(segment.status) }}
                            </span>
                          </td>
                          <td class="py-1 pr-4">
                            {{ dateTime(segment.from) }}
                          </td>
                          <td class="py-1 pr-4">{{ segmentEnd(segment) }}</td>
                          <td class="py-1 pr-4">
                            {{ duration(segment.duration) }}
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
                <div>
                  <h4
                    class="mb-2 text-xs font-medium uppercase text-n-slate-11"
                  >
                    {{ $t('AGENT_ACTIVITY_REPORTS.DETAIL.DAILY') }}
                  </h4>
                  <p v-if="!row.daily.length" class="text-xs text-n-slate-11">
                    {{ $t('AGENT_ACTIVITY_REPORTS.DETAIL.EMPTY') }}
                  </p>
                  <table v-else class="w-full text-xs">
                    <thead class="text-n-slate-11">
                      <tr>
                        <th class="py-1 pr-4 font-medium text-left">
                          {{ $t('AGENT_ACTIVITY_REPORTS.DETAIL.DATE') }}
                        </th>
                        <th class="py-1 pr-4 font-medium text-left">
                          {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.ONLINE_TIME') }}
                        </th>
                        <th class="py-1 pr-4 font-medium text-left">
                          {{ $t('AGENT_ACTIVITY_REPORTS.TABLE.BUSY_TIME') }}
                        </th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        v-for="day in row.daily"
                        :key="day.date"
                        class="border-t border-n-weak"
                      >
                        <td class="py-1 pr-4">{{ day.date }}</td>
                        <td class="py-1 pr-4">
                          {{ duration(day.online_seconds) }}
                        </td>
                        <td class="py-1 pr-4">
                          {{ duration(day.busy_seconds) }}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </td>
          </tr>
        </template>
      </tbody>
    </table>
  </div>
</template>
