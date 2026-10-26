<script>
import { CSAT_RATINGS } from 'shared/constants/messages';

// Xplus: five fixed columns so every rating fits on a phone, each with its name under the emoji
export default {
  props: {
    selectedRating: {
      type: Number,
      default: null,
    },
    isDisabled: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['selectRating'],
  data() {
    return {
      ratings: CSAT_RATINGS,
    };
  },

  methods: {
    isSelected(rating) {
      return rating.value === this.selectedRating;
    },
    emojiClass(rating) {
      return [
        { selected: this.isSelected(rating) },
        { disabled: this.isDisabled },
        'emoji text-3xl leading-none lg:text-4xl',
      ];
    },
    ratingLabel(rating) {
      return this.$t(
        `SURVEY.RATINGS.${rating.translationKey.split('.').pop()}`
      );
    },
    onClick(rating) {
      if (this.isDisabled) return;
      this.$emit('selectRating', rating.value);
    },
  },
};
</script>

<template>
  <div class="customer-satisfcation mb-2">
    <div class="ratings grid grid-cols-5 gap-1 py-5">
      <button
        v-for="rating in ratings"
        :key="rating.key"
        type="button"
        class="flex flex-col items-center min-w-0 gap-1.5 shadow-none outline-none group"
        :class="{ 'cursor-default pointer-events-none': isDisabled }"
        :aria-pressed="isSelected(rating)"
        @click="onClick(rating)"
      >
        <span :class="emojiClass(rating)">{{ rating.emoji }}</span>
        <span
          class="text-[11px] leading-tight text-center break-words"
          :class="
            isSelected(rating)
              ? 'font-medium text-n-slate-12'
              : 'text-n-slate-11'
          "
        >
          {{ ratingLabel(rating) }}
        </span>
      </button>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.emoji {
  filter: grayscale(100%);
  transition: transform 300ms;

  &.selected,
  .group:hover &,
  .group:focus-visible & {
    filter: grayscale(0%);
    transform: scale(1.2);
  }

  &.disabled {
    opacity: 0.5;
  }

  &.disabled.selected {
    opacity: 1;
  }
}
</style>
