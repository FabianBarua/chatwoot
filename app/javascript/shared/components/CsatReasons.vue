<script setup>
// Reasons a customer can pick after a low rating: one row of chips, the chosen one highlighted.
defineProps({
  reasons: { type: Array, default: () => [] },
  selectedReason: { type: String, default: null },
  isDisabled: { type: Boolean, default: false },
  accentColor: { type: String, default: '' },
});

const emit = defineEmits(['selectReason']);
</script>

<template>
  <div class="flex flex-wrap gap-2">
    <button
      v-for="reason in reasons"
      :key="reason"
      type="button"
      class="px-3 py-1.5 text-sm rounded-full border border-solid transition-colors outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      :class="[
        reason === selectedReason
          ? 'bg-n-brand text-white border-n-brand'
          : 'bg-n-background text-n-slate-12 border-n-weak hover:border-n-brand',
        isDisabled ? 'cursor-default opacity-70' : 'cursor-pointer',
      ]"
      :style="
        reason === selectedReason && accentColor
          ? { backgroundColor: accentColor, borderColor: accentColor }
          : {}
      "
      :disabled="isDisabled"
      @click="emit('selectReason', reason)"
    >
      {{ reason }}
    </button>
  </div>
</template>
