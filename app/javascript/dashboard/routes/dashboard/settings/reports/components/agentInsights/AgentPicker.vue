<script setup>
import { computed, nextTick, ref } from 'vue';
import { vOnClickOutside } from '@vueuse/components';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  agents: { type: Array, default: () => [] },
  modelValue: { type: [Number, String], default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const isOpen = ref(false);
const search = ref('');
const searchInput = ref(null);
const trigger = ref(null);
const optionRefs = ref([]);

const selected = computed(() =>
  props.agents.find(agent => String(agent.id) === String(props.modelValue))
);

const filteredAgents = computed(() => {
  const term = search.value.trim().toLowerCase();
  if (!term) return props.agents;
  return props.agents.filter(
    agent =>
      agent.name?.toLowerCase().includes(term) ||
      agent.email?.toLowerCase().includes(term)
  );
});

const close = ({ restoreFocus = false } = {}) => {
  isOpen.value = false;
  if (restoreFocus) trigger.value?.focus();
};

const toggle = async () => {
  if (isOpen.value) {
    close();
    return;
  }
  isOpen.value = true;
  search.value = '';
  await nextTick();
  searchInput.value?.focus();
};

const choose = id => {
  emit('update:modelValue', id);
  close({ restoreFocus: true });
};

// Arrow keys move between "All agents" and the filtered agents; Escape closes
const focusOption = index => {
  const options = optionRefs.value.filter(Boolean);
  if (!options.length) return;
  const next = (index + options.length) % options.length;
  options[next].focus();
};

const onListKeydown = event => {
  const options = optionRefs.value.filter(Boolean);
  const current = options.indexOf(document.activeElement);
  if (event.key === 'ArrowDown') {
    event.preventDefault();
    focusOption(current + 1);
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    if (current <= 0) searchInput.value?.focus();
    else focusOption(current - 1);
  } else if (event.key === 'Escape') {
    event.preventDefault();
    close({ restoreFocus: true });
  }
};

const onSearchKeydown = event => {
  if (event.key === 'ArrowDown') {
    event.preventDefault();
    focusOption(0);
  } else if (event.key === 'Enter' && filteredAgents.value.length === 1) {
    event.preventDefault();
    choose(filteredAgents.value[0].id);
  } else if (event.key === 'Escape') {
    event.preventDefault();
    close({ restoreFocus: true });
  }
};

const setOptionRef = (el, index) => {
  optionRefs.value[index] = el;
};
</script>

<template>
  <div v-on-click-outside="() => close()" class="relative w-full md:w-72">
    <button
      ref="trigger"
      type="button"
      class="flex items-center w-full h-9 gap-2 px-3 text-sm text-left rounded-lg outline outline-1 outline-n-weak bg-n-alpha-black2 hover:outline-n-strong focus-visible:outline-n-brand text-n-slate-12"
      :aria-expanded="isOpen"
      aria-haspopup="listbox"
      @click="toggle"
    >
      <Avatar
        v-if="selected"
        :src="selected.thumbnail"
        :name="selected.name"
        :status="selected.availability_status"
        :size="20"
        rounded-full
      />
      <Icon v-else icon="i-lucide-users" class="size-4 text-n-slate-11" />
      <span class="flex-1 truncate">
        {{ selected ? selected.name : t('AGENT_INSIGHTS.ALL_AGENTS') }}
      </span>
      <Icon
        icon="i-lucide-chevron-down"
        class="transition-transform size-4 text-n-slate-11"
        :class="{ 'rotate-180': isOpen }"
      />
    </button>

    <div
      v-if="isOpen"
      class="absolute z-20 w-full mt-1 overflow-hidden rounded-lg shadow-lg md:w-80 end-0 outline outline-1 outline-n-container bg-n-alpha-3 backdrop-blur-[100px]"
      @keydown="onListKeydown"
    >
      <div class="flex items-center gap-2 px-3 py-2 border-b border-n-weak">
        <Icon icon="i-lucide-search" class="size-4 text-n-slate-10" />
        <input
          ref="searchInput"
          v-model="search"
          type="search"
          class="!mb-0 w-full text-sm reset-base bg-transparent py-1 text-n-slate-12 placeholder:text-n-slate-10"
          :placeholder="t('AGENT_INSIGHTS.SEARCH_AGENT')"
          :aria-label="t('AGENT_INSIGHTS.SEARCH_AGENT')"
          @keydown.stop="onSearchKeydown"
        />
      </div>
      <ul
        class="py-1 m-0 overflow-y-auto list-none max-h-80"
        role="listbox"
        :aria-label="t('AGENT_INSIGHTS.SEARCH_AGENT')"
      >
        <li>
          <button
            :ref="el => setOptionRef(el, 0)"
            type="button"
            role="option"
            :aria-selected="!selected"
            class="flex items-center w-full gap-2 px-3 py-2 text-sm text-left outline-none hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2 text-n-slate-12"
            :class="{ 'bg-n-alpha-1': !selected }"
            @click="choose('')"
          >
            <span class="grid place-content-center size-6">
              <Icon icon="i-lucide-users" class="size-4 text-n-slate-11" />
            </span>
            <span class="flex-1">{{ t('AGENT_INSIGHTS.ALL_AGENTS') }}</span>
            <Icon v-if="!selected" icon="i-lucide-check" class="size-4" />
          </button>
        </li>
        <li v-for="(agent, index) in filteredAgents" :key="agent.id">
          <button
            :ref="el => setOptionRef(el, index + 1)"
            type="button"
            role="option"
            :aria-selected="selected?.id === agent.id"
            class="flex items-center w-full gap-2 px-3 py-2 text-sm text-left outline-none hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2 text-n-slate-12"
            :class="{ 'bg-n-alpha-1': selected?.id === agent.id }"
            @click="choose(agent.id)"
          >
            <Avatar
              :src="agent.thumbnail"
              :name="agent.name"
              :status="agent.availability_status"
              :size="24"
              rounded-full
            />
            <span class="flex flex-col flex-1 min-w-0">
              <span class="truncate">{{ agent.name }}</span>
              <span class="text-xs truncate text-n-slate-11">
                {{ agent.email }}
              </span>
            </span>
            <Icon
              v-if="selected?.id === agent.id"
              icon="i-lucide-check"
              class="size-4"
            />
          </button>
        </li>
        <li
          v-if="!filteredAgents.length"
          class="px-3 py-4 text-sm text-center text-n-slate-11"
        >
          {{ t('AGENT_INSIGHTS.NO_AGENT_FOUND') }}
        </li>
      </ul>
    </div>
  </div>
</template>
