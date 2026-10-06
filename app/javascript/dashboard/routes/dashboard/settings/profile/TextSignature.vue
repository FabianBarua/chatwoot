<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  TEXT_SIGNATURE_TYPES,
  TEXT_SIGNATURE_POSITIONS,
  getTextSignatureSettings,
} from 'dashboard/helper/textSignatureHelper';
import FormSelect from 'v3/components/Form/Select.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

const form = reactive(getTextSignatureSettings(uiSettings.value));

watch(
  () => uiSettings.value?.text_signature,
  () => Object.assign(form, getTextSignatureSettings(uiSettings.value))
);

const isTextRequired = computed(() => form.type !== 'original');

const typeOptions = TEXT_SIGNATURE_TYPES.map(value => ({
  value,
  label: t(`PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.TYPES.${value}`),
}));

const positionOptions = TEXT_SIGNATURE_POSITIONS.map(value => ({
  value,
  label: t(`PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.POSITIONS.${value}`),
}));

const EXAMPLE_MESSAGE = 'Hola, ¿qué tal?';

const preview = computed(() => {
  const text =
    form.text.trim() ||
    t('PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.TEXT.PLACEHOLDER');
  if (form.type === 'original') return EXAMPLE_MESSAGE;
  if (form.position === 'start') return `${text}\n${EXAMPLE_MESSAGE}`;
  if (form.position === 'start_inline') return `${text} ${EXAMPLE_MESSAGE}`;
  return `${EXAMPLE_MESSAGE}\n${text}`;
});

const save = async () => {
  if (isTextRequired.value && !form.text.trim()) {
    useAlert(t('PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.TEXT.ERROR'));
    return;
  }
  try {
    await updateUISettings({
      text_signature: {
        type: form.type,
        position: form.position,
        text: form.text.trim(),
      },
    });
    useAlert(t('PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.API_SUCCESS'));
  } catch (error) {
    useAlert(t('PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.API_ERROR'));
  }
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="save">
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
      <FormSelect
        v-model="form.type"
        name="textSignatureType"
        spacing="compact"
        :value="form.type"
        :options="typeOptions"
        :label="$t('PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.TYPE_LABEL')"
      >
        <option
          v-for="option in typeOptions"
          :key="option.value"
          :value="option.value"
          :selected="option.value === form.type"
        >
          {{ option.label }}
        </option>
      </FormSelect>
      <FormSelect
        v-model="form.position"
        name="textSignaturePosition"
        spacing="compact"
        :value="form.position"
        :options="positionOptions"
        :label="
          $t('PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.POSITION_LABEL')
        "
      >
        <option
          v-for="option in positionOptions"
          :key="option.value"
          :value="option.value"
          :selected="option.value === form.position"
        >
          {{ option.label }}
        </option>
      </FormSelect>
    </div>
    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.TEXT.LABEL') }}
      </span>
      <input
        v-model="form.text"
        type="text"
        maxlength="120"
        class="!mb-0"
        :disabled="!isTextRequired"
        :placeholder="
          $t('PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.TEXT.PLACEHOLDER')
        "
      />
    </label>
    <div class="flex flex-col gap-1">
      <span class="text-xs text-n-slate-11">
        {{ $t('PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.PREVIEW') }}
      </span>
      <pre
        class="px-3 py-2 text-sm whitespace-pre-wrap rounded-lg bg-n-slate-3 text-n-slate-12 font-sans"
        >{{ preview }}</pre
      >
    </div>
    <div>
      <NextButton
        type="submit"
        :label="$t('PROFILE_SETTINGS.FORM.TEXT_SIGNATURE_SECTION.BTN_TEXT')"
      />
    </div>
  </form>
</template>
