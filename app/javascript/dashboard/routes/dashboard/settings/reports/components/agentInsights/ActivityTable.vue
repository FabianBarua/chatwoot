<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { STATUS_DOT_CLASSES, formatCount, formatDuration } from './chartTheme';

const props = defineProps({
  rows: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  // Unix seconds where the report ends, to label the open segment as "now"
  rangeEnd: { type: Number, default: 0 },
});

const { t } = useI18n();

const STATUS_CLASSES = STATUS_DOT_CLASSES;
const expandedIds = ref([]);

const statusLabel = status =>
  t(`AGENT_ACTIVITY_REPORTS.STATUS.${status || 'offline'}`);
const duration = formatDuration;
const count = value => (value ? formatCount(value) : '--');
const dateTime = unix =>
  unix ? format(fromUnixTime(unix), 'dd/MM HH:mm') : '--';

const isExpanded = id => expandedIds.value.includes(id);
const toggleRow = id => {
  expandedIds.value = isExpanded(id)
    ? expandedIds.value.filter(item => item !== id)
    : [...expandedIds.value, id];
};

const segmentEnd = segment =>
  segment.to >= props.rangeEnd
    ? t('AGENT_ACTIVITY_REPORTS.DETAIL.NOW')
    : dateTime(segment.to);
</script>

<template>
  <div
    class="overflow-x-auto rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
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
