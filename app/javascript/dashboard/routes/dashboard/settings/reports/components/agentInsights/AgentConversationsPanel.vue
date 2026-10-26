<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';
import { useAlert } from 'dashboard/composables';
import ReportsAPI from 'dashboard/api/reports';
import { CSAT_RATINGS } from 'shared/constants/messages';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import InsightPanel from './InsightPanel.vue';
import FilterSelect from 'dashboard/components-next/filter/inputs/FilterSelect.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ShowMore from 'dashboard/components/widgets/ShowMore.vue';
import { formatCount } from './chartTheme';

// Xplus: the conversations an agent resolved in the period, filtered by the CSAT rating and the
// reason the customer picked. "none" asks the API for the ones without a rating / without a reason.
const props = defineProps({
  agentId: { type: [String, Number], required: true },
  since: { type: Number, required: true },
  until: { type: Number, required: true },
  // [{ reason, count }] from the agent insight, to offer only reasons that were actually used
  reasons: { type: Array, default: () => [] },
});

const { t } = useI18n();
const route = useRoute();

const ALL = 'all';
const NONE = 'none';

const rating = ref(ALL);
const reason = ref(ALL);
const page = ref(1);
const result = ref({ records: [], total_count: 0, per_page: 25 });
const isLoading = ref(false);

const ratingOptions = computed(() => [
  { value: ALL, label: t('AGENT_INSIGHTS.CONVERSATIONS.ALL_RATINGS') },
  ...[...CSAT_RATINGS]
    .sort((a, b) => b.value - a.value)
    .map(item => ({
      value: String(item.value),
      label: t(item.translationKey),
    })),
  { value: NONE, label: t('AGENT_INSIGHTS.CONVERSATIONS.NO_RATING') },
]);

const reasonOptions = computed(() => [
  { value: ALL, label: t('AGENT_INSIGHTS.CONVERSATIONS.ALL_REASONS') },
  ...props.reasons.map(item => ({
    value: item.reason,
    label: `${item.reason} (${formatCount(item.count)})`,
  })),
  { value: NONE, label: t('AGENT_INSIGHTS.CONVERSATIONS.NO_REASON') },
]);

const columns = [
  'CONVERSATION',
  'INBOX',
  'RESOLVED_AT',
  'RATING',
  'REASON',
  'FEEDBACK',
];

let requestId = 0;
const fetchConversations = async () => {
  requestId += 1;
  const current = requestId;
  isLoading.value = true;
  try {
    const { data } = await ReportsAPI.getAgentConversations(props.agentId, {
      since: props.since,
      until: props.until,
      rating: rating.value === ALL ? undefined : rating.value,
      reason: reason.value === ALL ? undefined : reason.value,
      page: page.value,
    });
    if (current === requestId) result.value = data;
  } catch (error) {
    useAlert(t('REPORT.DATA_FETCHING_FAILED'));
  } finally {
    if (current === requestId) isLoading.value = false;
  }
};

watch(
  () => [props.agentId, props.since, props.until, rating.value, reason.value],
  () => {
    page.value = 1;
    fetchConversations();
  },
  { immediate: true }
);

// A reason that is no longer offered (period changed) falls back to all
watch(reasonOptions, options => {
  if (!options.some(option => option.value === reason.value)) {
    reason.value = ALL;
  }
});

const goToPage = next => {
  page.value = next;
  fetchConversations();
};

const total = computed(() => result.value.total_count || 0);
const perPage = computed(() => result.value.per_page || 25);
const firstIndex = computed(() =>
  total.value ? (page.value - 1) * perPage.value + 1 : 0
);
const lastIndex = computed(() =>
  Math.min(page.value * perPage.value, total.value)
);
const hasPrevious = computed(() => page.value > 1);
const hasNext = computed(() => lastIndex.value < total.value);

const ratingData = value =>
  CSAT_RATINGS.find(item => item.value === value) || null;

const resolvedAt = unix => format(fromUnixTime(unix), 'dd/MM HH:mm');

const conversationPath = displayId =>
  frontendURL(
    conversationUrl({ accountId: route.params.accountId, id: displayId })
  );
</script>

<template>
  <InsightPanel
    :title="$t('AGENT_INSIGHTS.CONVERSATIONS.TITLE')"
    :description="$t('AGENT_INSIGHTS.CONVERSATIONS.DESCRIPTION')"
  >
    <template #actions>
      <div class="flex flex-wrap items-center gap-2">
        <FilterSelect
          v-model="rating"
          :options="ratingOptions"
          :label="$t('AGENT_INSIGHTS.CONVERSATIONS.FILTER_RATING')"
          hide-label
          variant="faded"
        />
        <FilterSelect
          v-model="reason"
          :options="reasonOptions"
          :label="$t('AGENT_INSIGHTS.CONVERSATIONS.FILTER_REASON')"
          hide-label
          variant="faded"
        />
      </div>
    </template>

    <div
      v-if="isLoading && !result.records.length"
      class="flex items-center justify-center gap-2 py-10 text-sm text-n-slate-11"
    >
      <Spinner />
      {{ $t('AGENT_INSIGHTS.CONVERSATIONS.LOADING') }}
    </div>
    <p
      v-else-if="!result.records.length"
      class="py-10 text-sm text-center text-n-slate-11"
    >
      {{ $t('AGENT_INSIGHTS.CONVERSATIONS.EMPTY') }}
    </p>
    <div
      v-else
      class="overflow-x-auto transition-opacity"
      :class="{ 'opacity-60': isLoading }"
    >
      <table class="w-full text-sm text-left">
        <thead class="text-xs text-n-slate-11 bg-n-slate-2">
          <tr>
            <th
              v-for="column in columns"
              :key="column"
              class="px-4 py-3 font-medium whitespace-nowrap"
            >
              {{ $t(`AGENT_INSIGHTS.CONVERSATIONS.COLUMNS.${column}`) }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in result.records"
            :key="row.id"
            class="border-t border-n-weak hover:bg-n-alpha-1"
          >
            <td class="px-4 py-2.5">
              <router-link
                :to="conversationPath(row.display_id)"
                class="flex flex-col gap-0.5 min-w-0"
              >
                <span class="font-medium text-n-slate-12 whitespace-nowrap">
                  {{ `#${row.display_id}` }}
                </span>
                <span class="text-xs truncate text-n-slate-11 max-w-48">
                  {{
                    row.contact.name ||
                    $t('AGENT_INSIGHTS.CONVERSATIONS.UNKNOWN_CONTACT')
                  }}
                </span>
              </router-link>
            </td>
            <td class="px-4 py-2.5 text-n-slate-11 whitespace-nowrap">
              <span class="inline-flex items-center gap-1.5">
                <Icon icon="i-lucide-inbox" class="size-3.5 text-n-slate-10" />
                {{ row.inbox.name }}
              </span>
            </td>
            <td
              class="px-4 py-2.5 tabular-nums text-n-slate-11 whitespace-nowrap"
            >
              {{ resolvedAt(row.resolved_at) }}
            </td>
            <td class="px-4 py-2.5 whitespace-nowrap">
              <span
                v-if="row.csat && ratingData(row.csat.rating)"
                class="inline-flex items-center px-2 py-1 text-sm font-medium rounded-lg text-n-slate-12"
                :style="{
                  backgroundColor: `${ratingData(row.csat.rating).color}20`,
                }"
              >
                {{ $t(ratingData(row.csat.rating).translationKey) }}
              </span>
              <span v-else class="text-sm italic text-n-slate-10">
                {{ $t('AGENT_INSIGHTS.CONVERSATIONS.NOT_RATED') }}
              </span>
            </td>
            <td class="px-4 py-2.5">
              <span v-if="row.csat?.reason" class="text-n-slate-12">
                {{ row.csat.reason }}
              </span>
              <span v-else-if="row.csat" class="text-sm italic text-n-slate-10">
                {{ $t('AGENT_INSIGHTS.CONVERSATIONS.NO_REASON') }}
              </span>
              <span v-else class="text-n-slate-10">{{ '--' }}</span>
            </td>
            <td class="px-4 py-2.5 min-w-64 text-n-slate-12">
              <ShowMore
                v-if="row.csat?.feedback_message"
                :text="row.csat.feedback_message"
                :limit="100"
              />
              <span v-else class="text-n-slate-10">{{ '--' }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div
      v-if="total > perPage"
      class="flex items-center justify-between gap-3 pt-4 mt-2 border-t border-n-weak"
    >
      <span class="text-xs tabular-nums text-n-slate-11">
        {{
          $t('AGENT_INSIGHTS.CONVERSATIONS.SHOWING', {
            from: firstIndex,
            to: lastIndex,
            total: formatCount(total),
          })
        }}
      </span>
      <div class="flex items-center gap-2">
        <Button
          ghost
          slate
          xs
          icon="i-lucide-chevron-left"
          :label="$t('AGENT_INSIGHTS.CONVERSATIONS.PREVIOUS')"
          :disabled="!hasPrevious || isLoading"
          @click="goToPage(page - 1)"
        />
        <Button
          ghost
          slate
          xs
          trailing-icon
          icon="i-lucide-chevron-right"
          :label="$t('AGENT_INSIGHTS.CONVERSATIONS.NEXT')"
          :disabled="!hasNext || isLoading"
          @click="goToPage(page + 1)"
        />
      </div>
    </div>
  </InsightPanel>
</template>
