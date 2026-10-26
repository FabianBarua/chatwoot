<script>
import { mapGetters } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import { CSAT_RATINGS, CSAT_DISPLAY_TYPES } from 'shared/constants/messages';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import StarRating from 'shared/components/StarRating.vue';
import CsatReasons from 'shared/components/CsatReasons.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getContrastingTextColor } from '@chatwoot/utils';

export default {
  components: {
    Spinner,
    FluentIcon,
    StarRating,
    CsatReasons,
  },
  props: {
    messageContentAttributes: {
      type: Object,
      default: () => {},
    },
    messageId: {
      type: Number,
      required: true,
    },
    displayType: {
      type: String,
      default: CSAT_DISPLAY_TYPES.EMOJI,
    },
    message: {
      type: String,
      default: '',
    },
  },
  setup() {
    const { formatMessage } = useMessageFormatter();
    return { formatMessage };
  },
  data() {
    return {
      email: '',
      ratings: CSAT_RATINGS,
      selectedRating: null,
      selectedReason: null,
      isUpdating: false,
      feedback: '',
    };
  },
  computed: {
    ...mapGetters({ widgetColor: 'appConfig/getWidgetColor' }),
    isRatingSubmitted() {
      return this.messageContentAttributes?.csat_survey_response?.rating;
    },
    isFeedbackSubmitted() {
      return this.messageContentAttributes?.csat_survey_response
        ?.feedback_message;
    },
    isButtonDisabled() {
      if (!(this.selectedRating && this.feedback)) return true;
      if (this.isUpdating) return true;
      return false;
    },
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
    title() {
      return this.isRatingSubmitted
        ? this.$t('CSAT.SUBMITTED_TITLE')
        : this.message || this.$t('CSAT.TITLE');
    },
    formattedTitle() {
      return this.formatMessage(this.title, false);
    },
    isEmojiType() {
      return this.displayType === CSAT_DISPLAY_TYPES.EMOJI;
    },
    isStarType() {
      return this.displayType === CSAT_DISPLAY_TYPES.STAR;
    },
    // Xplus: reasons offered after a low rating, from the inbox config or the widget's default list
    reasonOptions() {
      const configured = this.messageContentAttributes?.reasons;
      if (Array.isArray(configured)) return configured;
      const defaults = this.$tm('CSAT.REASONS_DEFAULTS');
      const list =
        Array.isArray(defaults) && defaults.length
          ? defaults
          : this.$i18n.getLocaleMessage('en').CSAT.REASONS_DEFAULTS;
      return list.map(item => this.$rt(item));
    },
    reasonsMaxRating() {
      return this.messageContentAttributes?.reasons_max_rating || 2;
    },
    // Right after the click, before the updated message comes back over the socket
    shouldShowReasons() {
      return (
        !!this.selectedRating &&
        this.selectedRating <= this.reasonsMaxRating &&
        this.reasonOptions.length > 0
      );
    },
  },

  mounted() {
    if (this.isRatingSubmitted) {
      const {
        csat_survey_response: { rating, feedback_message, reason },
      } = this.messageContentAttributes;
      this.selectedRating = rating;
      this.selectedReason = reason || null;
      this.feedback = feedback_message;
    }
  },

  methods: {
    buttonClass(rating) {
      const isLocked = this.isFeedbackSubmitted || this.isUpdating;
      return [
        { selected: rating.value === this.selectedRating },
        { disabled: isLocked },
        { hover: isLocked },
        'emoji-button',
      ];
    },
    async onSubmit() {
      if (this.isUpdating) return;
      this.isUpdating = true;
      try {
        await this.$store.dispatch('message/update', {
          submittedValues: {
            csat_survey_response: {
              rating: this.selectedRating,
              reason: this.selectedReason,
              feedback_message: this.feedback,
            },
          },
          messageId: this.messageId,
        });
      } catch (error) {
        // Ignore error
      } finally {
        this.isUpdating = false;
      }
    },

    selectRating(rating) {
      this.selectStarRating(rating.value);
    },
    selectStarRating(value) {
      if (this.isFeedbackSubmitted || this.isUpdating) return;
      this.selectedRating = value;
      // A reason only makes sense for the low rating it was picked for
      if (value > this.reasonsMaxRating) this.selectedReason = null;
      this.onSubmit();
    },
    selectReason(reason) {
      if (this.isFeedbackSubmitted || this.isUpdating) return;
      this.selectedReason = reason === this.selectedReason ? null : reason;
      this.onSubmit();
    },
  },
};
</script>

<template>
  <div
    class="customer-satisfaction w-full bg-n-background dark:bg-n-solid-3 shadow-[0_0.25rem_6px_rgba(50,50,93,0.08),0_1px_3px_rgba(0,0,0,0.05)] ltr:rounded-bl-[0.25rem] rtl:rounded-br-[0.25rem] rounded-lg inline-block leading-[1.5] mt-1 border-t-2 border-t-n-brand border-solid"
    :style="{ borderColor: widgetColor }"
  >
    <h6
      v-dompurify-html="formattedTitle"
      class="text-n-slate-12 text-sm font-medium pt-5 px-2.5 text-center prose prose-bubble"
    />
    <div v-if="isEmojiType" class="ratings flex justify-around py-5 px-4">
      <button
        v-for="rating in ratings"
        :key="rating.key"
        :class="buttonClass(rating)"
        @click="selectRating(rating)"
      >
        {{ rating.emoji }}
      </button>
    </div>
    <StarRating
      v-else-if="isStarType"
      :selected-rating="selectedRating"
      :is-disabled="isFeedbackSubmitted || isUpdating"
      @select-rating="selectStarRating"
    />
    <div v-if="shouldShowReasons" class="px-2.5 pb-4">
      <p class="mb-2 text-sm text-center text-n-slate-11">
        {{ $t('CSAT.REASONS_TITLE') }}
      </p>
      <CsatReasons
        class="justify-center"
        :reasons="reasonOptions"
        :selected-reason="selectedReason"
        :is-disabled="isFeedbackSubmitted || isUpdating"
        :accent-color="widgetColor"
        @select-reason="selectReason"
      />
    </div>
    <form
      v-if="!isFeedbackSubmitted"
      class="feedback-form flex"
      @submit.prevent="onSubmit()"
    >
      <input
        v-model="feedback"
        :placeholder="$t('CSAT.PLACEHOLDER')"
        @keydown.enter="onSubmit"
      />
      <button
        class="button small"
        :disabled="isButtonDisabled"
        :style="{
          background: widgetColor,
          borderColor: widgetColor,
          color: textColor,
        }"
      >
        <Spinner v-if="isUpdating && feedback" />
        <FluentIcon v-else icon="chevron-right" class="rtl:rotate-180" />
      </button>
    </form>
  </div>
</template>

<style lang="scss" scoped>
.customer-satisfaction {
  .ratings {
    .emoji-button {
      @apply shadow-none grayscale text-2xl outline-none transition-all duration-200;

      &.selected,
      &:hover,
      &:focus,
      &:active {
        @apply grayscale-0 scale-[1.32];
      }

      &.disabled {
        @apply cursor-not-allowed opacity-50 pointer-events-none;
      }
    }
  }

  .feedback-form {
    input {
      @apply h-10 dark:bg-n-alpha-black1 rtl:rounded-tl-[0] rtl:rounded-tr-[0] ltr:rounded-tr-[0] ltr:rounded-tl-[0] rtl:rounded-bl-[0] ltr:rounded-br-[0] ltr:rounded-bl-[0.25rem] rtl:rounded-br-[0.25rem] rounded-lg p-2.5 w-full focus:ring-0 focus:outline-n-brand;

      &::placeholder {
        @apply text-n-slate-10;
      }
    }

    .button {
      @apply rtl:rounded-tr-[0] rtl:rounded-tl-[0] appearance-none ltr:rounded-tl-[0] ltr:rounded-tr-[0] rtl:rounded-br-[0] ltr:rounded-bl-[0] rounded-lg h-auto ltr:-ml-px rtl:-mr-px text-xl;

      .spinner {
        display: block;
        padding: 0;
        height: auto;
        width: auto;
      }
    }
  }
}
</style>
