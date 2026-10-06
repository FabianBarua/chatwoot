<script setup>
import { computed, nextTick, ref, useTemplateRef } from 'vue';
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

// Tabs whose conversations are waiting on an agent: a non-zero count is highlighted
const ATTENTION_TABS = ['unattended', 'transferred'];

// Width per tab from which every tab can show its name on one line
const MIN_LABELLED_TAB_WIDTH = 112;

const container = useTemplateRef('container');
const tabRefs = ref([]);
const { width } = useElementSize(container);

// Narrow list: only the active tab shows its name, the rest are icon + count.
// Wide list: every tab shows icon, name and count. Either way nothing wraps.
const showAllLabels = computed(
  () =>
    props.items.length > 0 &&
    width.value / props.items.length >= MIN_LABELLED_TAB_WIDTH
);

const activeTabIndex = computed(() =>
  props.items.findIndex(item => item.key === props.activeTab)
);

const isActive = item => item.key === props.activeTab;
const showsLabel = item => showAllLabels.value || isActive(item);
const needsAttention = item =>
  ATTENTION_TABS.includes(item.key) && item.count > 0;

// Keeps four-digit totals from widening an icon-only tab
const formatCount = count =>
  count >= 1000 ? `${Math.floor(count / 100) / 10}k` : String(count);

const toneClass = item => {
  if (isActive(item)) return 'text-n-blue-11';
  if (needsAttention(item)) return 'text-n-amber-11';
  return '';
};

const countClass = item => {
  if (isActive(item)) return 'text-n-blue-11';
  if (needsAttention(item)) return 'text-n-amber-11';
  if (!item.count) return 'text-n-slate-10';
  return 'text-n-slate-12';
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
    class="flex w-full gap-0.5 px-1 border-b border-n-weak"
  >
    <button
      v-for="(item, index) in items"
      :key="item.key"
      :ref="el => (tabRefs[index] = el)"
      v-tooltip.bottom="showsLabel(item) ? null : item.name"
      type="button"
      role="tab"
      :aria-selected="isActive(item)"
      :aria-label="`${item.name}: ${item.count}`"
      :tabindex="isActive(item) ? 0 : -1"
      class="group relative -mb-px flex h-10 min-w-0 items-center justify-center gap-1.5 px-2 select-none outline-none whitespace-nowrap transition-colors duration-150 focus-visible:rounded-md focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-n-brand"
      :class="[
        showAllLabels || !isActive(item) ? 'flex-1' : 'flex-none',
        isActive(item)
          ? 'text-n-slate-12'
          : 'text-n-slate-11 hover:text-n-slate-12',
      ]"
      @click="onTabChange(index)"
      @keydown="onKeydown($event, index)"
    >
      <Icon
        :icon="TAB_ICONS[item.key] || 'i-lucide-list'"
        class="flex-shrink-0 size-4"
        :class="toneClass(item)"
      />
      <span
        v-if="showsLabel(item)"
        class="text-sm truncate"
        :class="isActive(item) ? 'font-semibold' : 'font-medium'"
      >
        {{ item.name }}
      </span>
      <span
        class="text-xs font-semibold tabular-nums"
        :class="countClass(item)"
      >
        {{ formatCount(item.count) }}
      </span>
      <span
        class="absolute bottom-0 inset-x-2 h-0.5 rounded-full transition-colors duration-150"
        :class="
          isActive(item)
            ? 'bg-n-brand'
            : 'bg-transparent group-hover:bg-n-slate-6'
        "
      />
    </button>
  </div>
</template>
