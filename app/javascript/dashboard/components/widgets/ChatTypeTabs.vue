<script setup>
import { computed, nextTick, ref, useTemplateRef } from 'vue';
import { useElementSize } from '@vueuse/core';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  activeTab: {
    type: String,
    default: wootConstants.ASSIGNEE_TYPE.ME,
  },
});

const emit = defineEmits(['chatTabChange']);

// Tabs whose conversations are waiting on an agent: a non-zero count is highlighted
const ATTENTION_TABS = ['unattended', 'transferred'];

// Static class names so Tailwind generates them (agents see 3 to 5 tabs depending on permissions)
const GRID_COLUMNS = {
  1: 'grid-cols-1',
  2: 'grid-cols-2',
  3: 'grid-cols-3',
  4: 'grid-cols-4',
  5: 'grid-cols-5',
};

// Below this width per tab the count goes above the name instead of beside it
const MIN_INLINE_TAB_WIDTH = 112;

const container = useTemplateRef('container');
const tabRefs = ref([]);
const { width } = useElementSize(container);

const isInline = computed(
  () =>
    props.items.length > 0 &&
    width.value / props.items.length >= MIN_INLINE_TAB_WIDTH
);

const activeTabIndex = computed(() =>
  props.items.findIndex(item => item.key === props.activeTab)
);

const isActive = item => item.key === props.activeTab;
const needsAttention = item =>
  ATTENTION_TABS.includes(item.key) && item.count > 0;

const countClass = item => {
  if (isActive(item)) return 'text-n-blue-11';
  if (needsAttention(item)) return 'text-n-amber-11';
  if (!item.count) return 'text-n-slate-10';
  return 'text-n-slate-12';
};

const badgeClass = item => {
  if (isActive(item)) return 'bg-n-blue-3 text-n-blue-11';
  if (needsAttention(item)) return 'bg-n-amber-3 text-n-amber-11';
  return 'bg-n-alpha-1 text-n-slate-10';
};

const onTabChange = selectedTabIndex => {
  if (selectedTabIndex < 0 || selectedTabIndex >= props.items.length) return;
  const selectedItem = props.items[selectedTabIndex];
  if (selectedItem.key !== props.activeTab) {
    emit('chatTabChange', selectedItem.key);
  }
};

// Arrow keys move between tabs (WAI-ARIA tabs pattern with automatic activation)
const focusTab = async index => {
  const count = props.items.length;
  const target = (index + count) % count;
  onTabChange(target);
  await nextTick();
  tabRefs.value[target]?.focus();
};

const onKeydown = (event, index) => {
  const moves = {
    ArrowRight: index + 1,
    ArrowLeft: index - 1,
    Home: 0,
    End: props.items.length - 1,
  };
  if (!(event.key in moves)) return;
  event.preventDefault();
  focusTab(moves[event.key]);
};

const keyboardEvents = {
  'Alt+KeyN': {
    action: () => {
      onTabChange((activeTabIndex.value + 1) % props.items.length);
    },
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <div
    ref="container"
    role="tablist"
    class="grid w-full px-0.5 border-b border-n-weak"
    :class="GRID_COLUMNS[items.length] || 'grid-cols-5'"
  >
    <button
      v-for="(item, index) in items"
      :key="item.key"
      :ref="el => (tabRefs[index] = el)"
      v-tooltip.bottom="isInline ? null : item.name"
      type="button"
      role="tab"
      :aria-selected="isActive(item)"
      :aria-label="`${item.name} ${item.count}`"
      :tabindex="isActive(item) ? 0 : -1"
      class="group relative -mb-px flex min-w-0 select-none outline-none transition-colors duration-150 focus-visible:rounded-md focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-n-brand"
      :class="[
        isInline
          ? 'h-10 flex-row items-center justify-center gap-1.5 px-2'
          : 'flex-col items-center gap-0.5 px-0 pt-2 pb-2.5',
        isActive(item)
          ? 'text-n-slate-12'
          : 'text-n-slate-11 hover:text-n-slate-12',
      ]"
      @click="onTabChange(index)"
      @keydown="onKeydown($event, index)"
    >
      <template v-if="isInline">
        <span class="text-sm font-medium truncate">{{ item.name }}</span>
        <span
          class="flex items-center justify-center h-5 min-w-5 px-1.5 rounded-full text-xs font-medium tabular-nums"
          :class="badgeClass(item)"
        >
          {{ item.count }}
        </span>
      </template>
      <template v-else>
        <span
          class="text-[0.9375rem] leading-5 font-semibold tabular-nums"
          :class="countClass(item)"
        >
          {{ item.count }}
        </span>
        <span
          class="w-full text-[0.6875rem] leading-[0.875rem] tracking-tight text-center line-clamp-2"
          :class="isActive(item) ? 'font-semibold' : 'font-medium'"
        >
          {{ item.name }}
        </span>
      </template>
      <span
        class="absolute bottom-0 h-0.5 rounded-full transition-colors duration-150"
        :class="[
          isInline ? 'inset-x-2' : 'inset-x-3',
          isActive(item)
            ? 'bg-n-brand'
            : 'bg-transparent group-hover:bg-n-slate-6',
        ]"
      />
    </button>
  </div>
</template>
