<script setup>
import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';
import { useI18n } from 'vue-i18n';
import { formatDuration } from './chartTheme';

// Rows of status bars on a 24 h axis. Each row has its own window ({ start, end } in unix
// seconds) and the status segments from the activity report, which are clipped to it.
const props = defineProps({
  rows: { type: Array, default: () => [] },
  labelWidth: { type: String, default: '9rem' },
});

const { t } = useI18n();

const HOURS = [0, 3, 6, 9, 12, 15, 18, 21];

const SEGMENT_CLASSES = {
  online: 'bg-n-teal-9',
  busy: 'bg-n-amber-9',
};

const visibleSegments = row =>
  row.segments
    .filter(
      seg =>
        SEGMENT_CLASSES[seg.status] && seg.to > row.start && seg.from < row.end
    )
    .map(seg => {
      const from = Math.max(seg.from, row.start);
      const to = Math.min(seg.to, row.end);
      const span = row.end - row.start;
      return {
        ...seg,
        from,
        to,
        left: ((from - row.start) / span) * 100,
        width: Math.max(((to - from) / span) * 100, 0.3),
      };
    });

const tooltip = seg =>
  `${t(`AGENT_ACTIVITY_REPORTS.STATUS.${seg.status}`)} · ${format(fromUnixTime(seg.from), 'HH:mm')}–${format(fromUnixTime(seg.to), 'HH:mm')} (${formatDuration(seg.to - seg.from)})`;

const nowOffset = row => {
  const now = Date.now() / 1000;
  if (now < row.start || now > row.end) return null;
  return ((now - row.start) / (row.end - row.start)) * 100;
};
</script>

<template>
  <div class="overflow-x-auto">
    <div class="min-w-[40rem]">
      <div
        class="grid items-end gap-x-3 pb-1"
        :style="{ gridTemplateColumns: `${props.labelWidth} 1fr` }"
      >
        <span />
        <div class="relative h-4 text-xs text-n-slate-10">
          <span
            v-for="hour in HOURS"
            :key="hour"
            class="absolute -translate-x-1/2 tabular-nums first:translate-x-0"
            :style="{ left: `${(hour / 24) * 100}%` }"
          >
            {{ `${String(hour).padStart(2, '0')}h` }}
          </span>
        </div>
      </div>
      <div
        v-for="row in props.rows"
        :key="row.id"
        class="grid items-center py-1.5 gap-x-3"
        :style="{ gridTemplateColumns: `${props.labelWidth} 1fr` }"
      >
        <div class="flex flex-col min-w-0">
          <span class="text-sm truncate text-n-slate-12">{{ row.label }}</span>
          <span v-if="row.sublabel" class="text-xs truncate text-n-slate-11">
            {{ row.sublabel }}
          </span>
        </div>
        <div class="relative h-6 overflow-hidden rounded-md bg-n-alpha-2">
          <span
            v-for="hour in HOURS.slice(1)"
            :key="hour"
            class="absolute inset-y-0 w-px bg-n-weak"
            :style="{ left: `${(hour / 24) * 100}%` }"
          />
          <span
            v-for="seg in visibleSegments(row)"
            :key="seg.from"
            v-tooltip.top="tooltip(seg)"
            class="absolute inset-y-1 rounded-sm"
            :class="SEGMENT_CLASSES[seg.status]"
            :style="{ left: `${seg.left}%`, width: `${seg.width}%` }"
          />
          <span
            v-if="nowOffset(row) !== null"
            class="absolute inset-y-0 w-0.5 bg-n-ruby-9"
            :style="{ left: `${nowOffset(row)}%` }"
          />
        </div>
      </div>
      <div class="flex items-center gap-4 mt-3 text-xs text-n-slate-11">
        <span class="inline-flex items-center gap-1.5">
          <span class="rounded-sm size-2.5 bg-n-teal-9" />
          {{ $t('AGENT_ACTIVITY_REPORTS.STATUS.online') }}
        </span>
        <span class="inline-flex items-center gap-1.5">
          <span class="rounded-sm size-2.5 bg-n-amber-9" />
          {{ $t('AGENT_ACTIVITY_REPORTS.STATUS.busy') }}
        </span>
        <span class="inline-flex items-center gap-1.5">
          <span class="rounded-sm size-2.5 bg-n-alpha-2" />
          {{ $t('AGENT_ACTIVITY_REPORTS.STATUS.offline') }}
        </span>
      </div>
    </div>
  </div>
</template>
