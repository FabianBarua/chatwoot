<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import wootConstants from 'dashboard/constants/globals';
import ConversationApi from 'dashboard/api/inbox/conversation';

import Banner from 'dashboard/components/ui/Banner.vue';

const props = defineProps({
  message: {
    type: String,
    default: '',
  },
  isOnPrivateNote: {
    type: Boolean,
    default: false,
  },
});

const store = useStore();
const { t } = useI18n();

const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');

const assignedAgent = computed({
  get() {
    return currentChat.value?.meta?.assignee;
  },
  set(agent) {
    const agentId = agent ? agent.id : null;
    store.dispatch('setCurrentChatAssignee', {
      conversationId: currentChat.value?.id,
      assignee: agent,
      assigneeType: agent ? 'User' : null,
    });
    store.dispatch('assignAgent', {
      conversationId: currentChat.value?.id,
      agentId,
    });
  },
});

const hasMessage = computed(() => props.message !== '');
const isUserTyping = computed(() => hasMessage.value && !props.isOnPrivateNote);
const isUnassigned = computed(() => !assignedAgent.value);
const isAssignedToOtherAgent = computed(
  () => assignedAgent.value?.id !== currentUser.value?.id
);

const showSelfAssignBanner = computed(() => {
  return (
    isUserTyping.value && (isUnassigned.value || isAssignedToOtherAgent.value)
  );
});

const isPendingConversation = computed(
  () => currentChat.value?.status === wootConstants.STATUS_TYPE.PENDING
);

const isAgentBotOwned = computed(
  () => currentChat.value?.meta?.assignee_type === 'AgentBot'
);

const showBotHandoffBanner = computed(() => {
  return isPendingConversation.value && isAgentBotOwned.value;
});

const botAssigneeName = computed(() => {
  if (isAgentBotOwned.value && assignedAgent.value?.name) {
    return assignedAgent.value.name;
  }

  return t('CONVERSATION.BOT_HANDOFF_FALLBACK_ASSIGNEE');
});

// Step the bot is on, set by the bot as the sox_step conversation attribute
const botStep = computed(
  () => currentChat.value?.custom_attributes?.sox_step || ''
);

const botHandoffMessage = computed(() =>
  botStep.value
    ? t('CONVERSATION.BOT_HANDOFF_MESSAGE_WITH_STEP', {
        assigneeName: botAssigneeName.value,
        step: botStep.value,
      })
    : t('CONVERSATION.BOT_HANDOFF_MESSAGE', {
        assigneeName: botAssigneeName.value,
      })
);

const selfAssignConversation = async () => {
  const { avatar_url, ...rest } = currentUser.value || {};
  assignedAgent.value = { ...rest, thumbnail: avatar_url };
};

const onClickSelfAssign = async () => {
  try {
    await selfAssignConversation();
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } catch (error) {
    useAlert(t('CONVERSATION.CHANGE_AGENT_FAILED'));
  }
};

const HANDOFF_RETRY_DELAY_MS = 800;

// No response (network, proxy), 429 or 5xx: the request may never have
// reached Rails, so it is worth one more try.
const isTransientError = error => {
  const status = error?.response?.status;
  return !status || status === 429 || status >= 500;
};

const requestWithRetry = async request => {
  try {
    return await request();
  } catch (error) {
    if (!isTransientError(error)) throw error;
    await new Promise(resolve => {
      setTimeout(resolve, HANDOFF_RETRY_DELAY_MS);
    });
    return request();
  }
};

const isHandingOff = ref(false);

// Talks to the API directly and confirms on the server before telling the
// agent: the store actions swallow errors, so the UI used to say "handed
// over" even when the request never went through and the bot kept the chat.
const onClickBotHandoff = async () => {
  const conversationId = currentChat.value?.id;
  if (!conversationId || isHandingOff.value) return;

  isHandingOff.value = true;
  try {
    await requestWithRetry(() =>
      ConversationApi.toggleStatus({ conversationId, status: 'open' })
    );
    await requestWithRetry(() =>
      ConversationApi.assignAgent({
        conversationId,
        agentId: currentUser.value?.id,
        assigneeType: 'User',
      })
    );
    const { data } = await ConversationApi.show(conversationId);
    await store.dispatch('updateConversation', data);
    if (data.status !== wootConstants.STATUS_TYPE.OPEN) {
      throw new Error(`conversation ${conversationId} still ${data.status}`);
    }
    useAlert(t('CONVERSATION.BOT_HANDOFF_SUCCESS'));
  } catch (error) {
    const status = error?.response?.status;
    useAlert(
      status
        ? t('CONVERSATION.BOT_HANDOFF_ERROR_HTTP', { status })
        : t('CONVERSATION.BOT_HANDOFF_ERROR')
    );
  } finally {
    isHandingOff.value = false;
  }
};
</script>

<template>
  <Banner
    v-if="showSelfAssignBanner && !showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="$t('CONVERSATION.NOT_ASSIGNED_TO_YOU')"
    has-action-button
    :action-button-label="$t('CONVERSATION.ASSIGN_TO_ME')"
    @primary-action="onClickSelfAssign"
  />
  <Banner
    v-if="showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="botHandoffMessage"
    has-action-button
    :action-button-label="$t('CONVERSATION.BOT_HANDOFF_ACTION')"
    @primary-action="onClickBotHandoff"
  />
</template>
