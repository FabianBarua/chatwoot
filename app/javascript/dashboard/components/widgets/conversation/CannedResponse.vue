<script setup>
import { computed, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { picoSearch } from '@chatwoot/pico-search';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import {
  resolveVariablesInMessage,
  stripUnsupportedFormatting,
} from 'dashboard/helper/editorHelper';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import CaretAnchoredPicker from 'dashboard/components-next/preview-picker/CaretAnchoredPicker.vue';

const props = defineProps({
  caretPosition: {
    type: Object,
    default: null,
  },
  searchKey: {
    type: String,
    default: '',
  },
  variables: {
    type: Object,
    default: () => ({}),
  },
  schema: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['replace', 'close', 'removeTrigger']);

// Characters kept before the match when a snippet has to skip ahead
const SNIPPET_LEAD = 24;
const HIGHLIGHT_CLASS = 'text-n-blue-text';

const store = useStore();
const { t } = useI18n();
const { getPlainText, formatMessage, highlightContent } = useMessageFormatter();

const cannedResponses = useMapGetter('getCannedResponses');
const uiFlags = useMapGetter('getUIFlags');
// The trigger can already be followed by text, from a draft or a caret moved back onto it
const searchQuery = ref(props.searchKey);

const searchTerm = computed(() => searchQuery.value.trim());

// An empty term makes `highlightContent`'s regex match at every position, wrapping the
// whole string in empty spans
const highlightMatches = text =>
  searchTerm.value
    ? highlightContent(text, searchTerm.value, HIGHLIGHT_CLASS)
    : text;

const buildSnippet = text => {
  const term = searchTerm.value;
  if (!term) return text;

  const index = text.toLowerCase().indexOf(term.toLowerCase());
  if (index <= SNIPPET_LEAD) return text;

  return `…${text.slice(index - SNIPPET_LEAD)}`;
};

// Both steps mirror what insertion does: variables are substituted, then formatting the
// channel's schema cannot carry is stripped. Previewing the raw content would advertise
// styling the message never ends up with.
const resolveContent = message =>
  stripUnsupportedFormatting(
    resolveVariablesInMessage(message, props.variables),
    props.schema
  );

const records = computed(() =>
  cannedResponses.value.map(
    ({ id, short_code: shortCode, content, files = [] }) => {
      const resolved = resolveContent(content || '');
      return {
        id,
        content: content || '',
        resolved,
        shortCode,
        files,
        plainText: getPlainText(resolved).replace(/\s+/g, ' ').trim(),
      };
    }
  )
);

const filteredRecords = computed(() => {
  if (!searchTerm.value) return records.value;

  return picoSearch(records.value, searchTerm.value, [
    { name: 'shortCode', weight: 1 },
    'plainText',
  ]);
});

const attachmentSummary = files =>
  files.length ? t('CANNED_MGMT.ATTACHMENTS.COUNT', { n: files.length }) : '';

const items = computed(() =>
  filteredRecords.value.map(record => ({
    id: record.id,
    content: record.content,
    resolved: record.resolved,
    files: record.files,
    label: `/${record.shortCode}`,
    title: highlightMatches(`/${record.shortCode}`),
    subtitle: highlightMatches(
      [attachmentSummary(record.files), buildSnippet(record.plainText)]
        .filter(Boolean)
        .join(' · ')
    ),
  }))
);

const isImage = file => (file.content_type || '').startsWith('image/');

// The editor inserts the text and hands the files to the reply box, which
// attaches them to the outgoing message.
const onSelect = item =>
  emit('replace', { content: item.content, files: item.files });

onMounted(() => store.dispatch('getCannedResponse'));
</script>

<template>
  <CaretAnchoredPicker
    v-model:search="searchQuery"
    :caret-position="caretPosition"
    :items="items"
    :search-placeholder="t('COMBOBOX.SEARCH_PLACEHOLDER')"
    :is-loading="uiFlags.fetchingList"
    :empty-label="
      searchTerm
        ? t('COMBOBOX.EMPTY_SEARCH_RESULTS', { searchTerm })
        : t('COMBOBOX.EMPTY_STATE')
    "
    @select="onSelect"
    @close="emit('close')"
    @remove-trigger="emit('removeTrigger')"
  >
    <template #preview="{ item }">
      <div class="px-4 py-3 flex flex-col gap-2">
        <div v-if="item?.files?.length" class="flex flex-wrap gap-2">
          <template v-for="file in item.files" :key="file.id">
            <img
              v-if="isImage(file)"
              :src="file.file_url"
              class="h-24 max-w-[12rem] object-cover rounded-md"
            />
            <span
              v-else
              class="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-md bg-n-slate-3 text-n-slate-12"
            >
              <span class="i-lucide-paperclip size-3.5" />
              {{ file.filename }}
            </span>
          </template>
        </div>
        <div
          v-if="item?.resolved"
          v-dompurify-html="formatMessage(item.resolved)"
          class="prose prose-bubble !max-w-none prose-a:text-n-brand"
        />
      </div>
    </template>
  </CaretAnchoredPicker>
</template>
