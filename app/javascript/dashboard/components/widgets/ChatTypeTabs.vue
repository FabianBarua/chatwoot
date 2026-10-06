<script setup>
import { computed, useTemplateRef } from 'vue';
import { useElementSize } from '@vueuse/core';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import wootConstants from 'dashboard/constants/globals';
import Icon from 'dashboard/components-next/icon/Icon.vue';

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

const TAB_ICONS = {
  me: 'i-lucide-user-round',
  unattended: 'i-lucide-clock-alert',
  transferred: 'i-lucide-arrow-right-left',
  unassigned: 'i-lucide-user-round-x',
  all: 'i-lucide-inbox',
};

// Tabs that hold conversations waiting on an agent: their count is highlighted
const ATTENTION_TABS = ['unattended', 'transferred'];

// Static class names so Tailwind generates them (agents see 3 to 5 tabs depending on permissions)
const GRID_COLUMNS = {
  1: 'grid-cols-1',
  2: 'grid-cols-2',
  3: 'grid-cols-3',
  4: 'grid-cols-4',
  5: 'grid-cols-5',
};

// Below this width per tab the label moves under the icon and count
const MIN_INLINE_TAB_WIDTH = 104;

const container = useTemplateRef('container');
const { width } = useElementSize(container);

const isInline = computed(
  () =>
    props.items.length > 0 &&
    width.value / props.items.length >= MIN_INLINE_TAB_WIDTH
);

const activeTabIndex = computed(() =>
  props.items.findIndex(item => item.key === props.activeTab)
);

const needsAttention = item =>
  ATTENTION_TABS.includes(item.key) && item.count > 0;

const countClass = item => {
  if (item.key === props.activeTab) return 'text-n-blue-11';
  if (needsAttention(item)) return 'text-n-amber-11';
  return 'text-n-slate-11';
};

const onTabChange = selectedTabIndex => {
  if (selectedTabIndex < 0 || selectedTabIndex >= props.items.length) return;
  const selectedItem = props.items[selectedTabIndex];
  if (selectedItem.key !== props.activeTab) {
    emit('chatTabChange', selectedItem.key);
  }
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
    class="grid w-full gap-1 px-2 py-1.5 border-b border-n-weak"
    :class="GRID_COLUMNS[items.length] || 'grid-cols-5'"
  >
    <button
      v-for="(item, index) in items"
      :key="item.key"
      v-tooltip.bottom="isInline ? null : item.name"
      type="button"
      role="tab"
      :aria-selected="item.key === activeTab"
      class="relative flex min-w-0 rounded-lg transition-colors select-none"
      :class="[
        isInline
          ? 'flex-row items-center justify-center gap-1.5 h-8 px-2'
          : 'flex-col items-center justify-start gap-0.5 px-1 py-1.5',
        item.key === activeTab
          ? 'bg-n-alpha-2 text-n-slate-12'
          : 'text-n-slate-11 hover:bg-n-alpha-1 hover:text-n-slate-12',
      ]"
      @click="onTabChange(index)"
    >
      <span class="flex items-center gap-1">
        <Icon
          :icon="TAB_ICONS[item.key] || 'i-lucide-list'"
          class="flex-shrink-0 size-3.5"
          :class="item.key === activeTab ? 'text-n-blue-11' : ''"
        />
        <span
          v-if="!isInline"
          class="text-sm font-semibold tabular-nums"
          :class="countClass(item)"
        >
          {{ item.count }}
        </span>
      </span>
      <span
        class="font-medium"
        :class="
          isInline
            ? 'text-sm truncate'
            : 'text-[0.6875rem] leading-[0.8125rem] text-center line-clamp-2 break-words'
        "
      >
        {{ item.name }}
      </span>
      <span
        v-if="isInline"
        class="text-xs font-semibold tabular-nums"
        :class="countClass(item)"
      >
        {{ item.count }}
      </span>
      <span
        v-if="needsAttention(item) && item.key !== activeTab"
        class="absolute top-1 ltr:right-1 rtl:left-1 rounded-full size-1.5 bg-n-amber-9"
      />
    </button>
  </div>
</template>
