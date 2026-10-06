<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatBytes } from 'shared/helpers/FileHelper';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  existingFiles: {
    type: Array,
    default: () => [],
  },
});

const newFiles = defineModel('newFiles', { type: Array, default: () => [] });
const removedFileIds = defineModel('removedFileIds', {
  type: Array,
  default: () => [],
});

const { t } = useI18n();
const fileInput = ref(null);

const keptFiles = computed(() =>
  props.existingFiles.filter(file => !removedFileIds.value.includes(file.id))
);

const isImage = type => (type || '').startsWith('image/');

const onFilesSelected = event => {
  const selected = Array.from(event.target.files || []);
  newFiles.value = [...newFiles.value, ...selected];
  event.target.value = '';
};

const removeNewFile = index => {
  newFiles.value = newFiles.value.filter((_, i) => i !== index);
};

const removeExistingFile = id => {
  removedFileIds.value = [...removedFileIds.value, id];
};
</script>

<template>
  <div class="flex flex-col gap-2 w-full mb-4">
    <label>{{ t('CANNED_MGMT.ATTACHMENTS.LABEL') }}</label>
    <p class="text-xs text-n-slate-11 -mt-1">
      {{ t('CANNED_MGMT.ATTACHMENTS.HELP') }}
    </p>
    <ul v-if="keptFiles.length || newFiles.length" class="flex flex-col gap-1">
      <li
        v-for="file in keptFiles"
        :key="`existing-${file.id}`"
        class="flex items-center gap-2 p-1.5 rounded-md bg-n-slate-3"
      >
        <img
          v-if="isImage(file.content_type)"
          :src="file.file_url"
          class="w-8 h-8 object-cover rounded-sm flex-shrink-0"
        />
        <span v-else class="i-lucide-file w-5 h-5 text-n-slate-11" />
        <span class="text-sm truncate flex-1 min-w-0">{{ file.filename }}</span>
        <span class="text-xs text-n-slate-11">
          {{ formatBytes(file.byte_size, 0) }}
        </span>
        <Button
          ghost
          slate
          xs
          icon="i-lucide-x"
          type="button"
          @click="removeExistingFile(file.id)"
        />
      </li>
      <li
        v-for="(file, index) in newFiles"
        :key="`new-${index}-${file.name}`"
        class="flex items-center gap-2 p-1.5 rounded-md bg-n-slate-3"
      >
        <span class="i-lucide-upload w-5 h-5 text-n-blue-11" />
        <span class="text-sm truncate flex-1 min-w-0">{{ file.name }}</span>
        <span class="text-xs text-n-slate-11">
          {{ formatBytes(file.size, 0) }}
        </span>
        <Button
          ghost
          slate
          xs
          icon="i-lucide-x"
          type="button"
          @click="removeNewFile(index)"
        />
      </li>
    </ul>
    <input
      ref="fileInput"
      type="file"
      multiple
      accept="image/*,video/*,audio/*,application/pdf,.doc,.docx,.xls,.xlsx,.txt"
      class="hidden"
      @change="onFilesSelected"
    />
    <Button
      type="button"
      faded
      slate
      sm
      icon="i-lucide-paperclip"
      :label="t('CANNED_MGMT.ATTACHMENTS.ADD')"
      class="self-start"
      @click="fileInput.click()"
    />
  </div>
</template>
