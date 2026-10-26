<script>
import { useAlert } from 'dashboard/composables';
import Branding from 'shared/components/Branding.vue';
import Spinner from 'shared/components/Spinner.vue';
import Rating from 'survey/components/Rating.vue';
import Feedback from 'survey/components/Feedback.vue';
import Banner from 'survey/components/Banner.vue';
import StarRating from 'shared/components/StarRating.vue';
import CsatReasons from 'shared/components/CsatReasons.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getSurveyDetails, updateSurvey } from 'survey/api/survey';

import { CSAT_DISPLAY_TYPES } from 'shared/constants/messages';

export default {
  name: 'Response',
  components: {
    Branding,
    Rating,
    Spinner,
    Banner,
    Feedback,
    StarRating,
    CsatReasons,
  },
  setup() {
    const { formatMessage } = useMessageFormatter();
    return { formatMessage };
  },
  data() {
    return {
      surveyDetails: null,
      isLoading: false,
      errorMessage: null,
      selectedRating: null,
      selectedReason: null,
      // Xplus: reasons offered after a low rating; null means "use the default list"
      reasons: null,
      reasonsMaxRating: 2,
      feedbackMessage: '',
      hasSubmittedFeedback: false,
      isUpdating: false,
      logo: '',
      inboxName: '',
      displayType: CSAT_DISPLAY_TYPES.EMOJI,
      messageContent: '',
    };
  },
  computed: {
    surveyId() {
      const pageURL = window.location.href;
      return pageURL.substring(pageURL.lastIndexOf('/') + 1);
    },
    isRatingSubmitted() {
      return this.surveyDetails && this.surveyDetails.rating;
    },
    isFeedbackSubmitted() {
      return (
        this.hasSubmittedFeedback || !!this.surveyDetails?.feedback_message
      );
    },
    isButtonDisabled() {
      if (!this.selectedRating) return true;
      if (this.isUpdating) return true;
      return false;
    },
    isEmojiType() {
      return this.displayType === CSAT_DISPLAY_TYPES.EMOJI;
    },
    isStarType() {
      return this.displayType === CSAT_DISPLAY_TYPES.STAR;
    },
    shouldShowBanner() {
      return this.isRatingSubmitted || this.errorMessage;
    },
    enableFeedbackForm() {
      return !this.isFeedbackSubmitted && this.isRatingSubmitted;
    },
    reasonOptions() {
      if (Array.isArray(this.reasons)) return this.reasons;
      // Default list in the survey language, English when the language has none
      const defaults = this.$tm('SURVEY.REASONS.DEFAULTS');
      const list =
        Array.isArray(defaults) && defaults.length
          ? defaults
          : this.$i18n.getLocaleMessage('en').SURVEY.REASONS.DEFAULTS;
      return list.map(item => this.$rt(item));
    },
    shouldShowReasons() {
      return (
        this.isRatingSubmitted &&
        this.selectedRating <= this.reasonsMaxRating &&
        this.reasonOptions.length > 0
      );
    },
    shouldShowErrorMessage() {
      return !!this.errorMessage;
    },
    shouldShowSuccessMessage() {
      return !!this.isRatingSubmitted;
    },
    message() {
      if (this.errorMessage) {
        return this.errorMessage;
      }
      return this.$t('SURVEY.RATING.SUCCESS_MESSAGE');
    },
    formattedMessageContent() {
      return this.formatMessage(this.messageContent, false);
    },
  },
  async mounted() {
    this.getSurveyDetails();
  },
  methods: {
    selectRating(rating) {
      if (this.isFeedbackSubmitted || this.isUpdating) return;
      this.selectedRating = rating;
      // A reason only makes sense for the low rating it was picked for
      if (rating > this.reasonsMaxRating) this.selectedReason = null;
      this.updateSurveyDetails();
    },
    selectReason(reason) {
      if (this.isFeedbackSubmitted || this.isUpdating) return;
      this.selectedReason = reason === this.selectedReason ? null : reason;
      this.updateSurveyDetails();
    },
    sendFeedback(message) {
      this.feedbackMessage = message;
      this.updateSurveyDetails({ markFeedbackSubmitted: true });
    },
    async getSurveyDetails() {
      this.isLoading = true;
      try {
        const result = await getSurveyDetails({ uuid: this.surveyId });
        this.logo = result.data.inbox_avatar_url;
        this.inboxName = result.data.inbox_name;
        this.surveyDetails = result?.data?.csat_survey_response;
        this.selectedRating = this.surveyDetails?.rating;
        this.selectedReason = this.surveyDetails?.reason || null;
        this.feedbackMessage = this.surveyDetails?.feedback_message || '';
        this.reasons = result.data.reasons ?? null;
        this.reasonsMaxRating = result.data.reasons_max_rating || 2;
        this.displayType = result.data.display_type || CSAT_DISPLAY_TYPES.EMOJI;
        this.messageContent =
          result.data.content ||
          this.$t('SURVEY.DESCRIPTION', { inboxName: this.inboxName });
        this.setLocale(result.data.locale);
      } catch (error) {
        const errorMessage = error?.response?.data?.message;
        this.errorMessage = errorMessage || this.$t('SURVEY.API.ERROR_MESSAGE');
      } finally {
        this.isLoading = false;
      }
    },
    async updateSurveyDetails({ markFeedbackSubmitted = false } = {}) {
      this.isUpdating = true;
      try {
        const data = {
          message: {
            submitted_values: {
              csat_survey_response: {
                rating: this.selectedRating,
                reason: this.selectedReason,
                feedback_message: this.feedbackMessage,
              },
            },
          },
        };
        await updateSurvey({
          uuid: this.surveyId,
          data,
        });
        this.surveyDetails = {
          rating: this.selectedRating,
          reason: this.selectedReason,
          feedback_message: this.feedbackMessage,
        };
        if (markFeedbackSubmitted) {
          this.hasSubmittedFeedback = true;
        }
      } catch (error) {
        const errorMessage = error?.response?.data?.error;
        this.errorMessage = errorMessage || this.$t('SURVEY.API.ERROR_MESSAGE');
        useAlert(this.errorMessage);
      } finally {
        this.isUpdating = false;
      }
    },
    setLocale(locale) {
      this.$root.$i18n.locale = locale || 'en';
    },
  },
};
</script>

<template>
  <div
    v-if="isLoading"
    class="flex items-center justify-center flex-1 h-full min-h-screen bg-n-background"
  >
    <Spinner size="" />
  </div>
  <div
    v-else
    class="flex items-center justify-center w-full h-full min-h-screen overflow-auto bg-n-background"
  >
    <div
      class="flex flex-col w-full h-full bg-n-solid-1 rounded-lg border border-solid border-n-weak shadow-md lg:w-2/5 lg:h-auto"
    >
      <div class="w-full px-6 pt-8 pb-6 m-auto my-0 sm:px-12 sm:pt-12">
        <img v-if="logo" :src="logo" alt="Chatwoot logo" class="mb-6 logo" />
        <div
          v-if="!isRatingSubmitted"
          v-dompurify-html="formattedMessageContent"
          class="mb-8 text-lg leading-relaxed text-n-slate-12 prose prose-bubble"
        />
        <Banner
          v-if="shouldShowBanner"
          :show-success="shouldShowSuccessMessage"
          :show-error="shouldShowErrorMessage"
          :message="message"
        />
        <label
          v-if="!isRatingSubmitted"
          class="mb-4 text-base font-medium text-n-slate-11"
        >
          {{ $t('SURVEY.RATING.LABEL') }}
        </label>
        <Rating
          v-if="isEmojiType"
          :selected-rating="selectedRating"
          :is-disabled="isFeedbackSubmitted || isUpdating"
          @select-rating="selectRating"
        />
        <StarRating
          v-if="isStarType"
          :selected-rating="selectedRating"
          :is-disabled="isFeedbackSubmitted || isUpdating"
          class="[&>button>span]:text-4xl !justify-start !px-0"
          @select-rating="selectRating"
        />
        <div v-if="shouldShowReasons" class="mt-6">
          <label class="text-base font-medium text-n-slate-12">
            {{ $t('SURVEY.REASONS.LABEL') }}
          </label>
          <p class="mt-1 mb-4 text-sm text-n-slate-11">
            {{ $t('SURVEY.REASONS.HINT') }}
          </p>
          <CsatReasons
            :reasons="reasonOptions"
            :selected-reason="selectedReason"
            :is-disabled="isFeedbackSubmitted || isUpdating"
            @select-reason="selectReason"
          />
        </div>
        <Feedback
          v-if="enableFeedbackForm"
          :is-updating="isUpdating"
          :is-button-disabled="isButtonDisabled"
          :selected-rating="selectedRating"
          @send-feedback="sendFeedback"
        />
      </div>
      <div class="mb-3">
        <Branding />
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.logo {
  max-height: 3rem;
}
</style>
