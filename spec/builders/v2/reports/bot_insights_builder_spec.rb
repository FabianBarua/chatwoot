require 'rails_helper'

RSpec.describe V2::Reports::BotInsightsBuilder do
  subject(:builder) { described_class.new(account: account, params: params) }

  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot, account: account, name: 'SuporteOficialX') }
  let(:inbox) { create(:inbox, account: account, name: 'API') }
  let(:other_inbox) { create(:inbox, account: account, name: 'Web') }
  let(:params) { { since: 7.days.ago.beginning_of_day.to_i.to_s, until: Time.current.end_of_day.to_i.to_s, timezone_offset: 0 } }

  before do
    create(:agent_bot_inbox, agent_bot: agent_bot, inbox: inbox)
  end

  def bot_conversation(**attributes)
    create(:conversation, { account: account, inbox: inbox, status: :pending, ai_assignee: agent_bot, created_at: 2.days.ago }.merge(attributes))
  end

  def event(name, conversation, value: 0, created_at: 1.day.ago)
    create(:reporting_event, account: account, inbox: conversation.inbox, conversation: conversation, user: nil,
                             name: name, value: value, created_at: created_at)
  end

  describe '#build' do
    let!(:resolved) { bot_conversation(cached_label_list: 'horarios', custom_attributes: { 'sox_title' => 'Horários' }) }
    let!(:abandoned) { bot_conversation(custom_attributes: { 'sox_step' => 'Menu: Horários', 'sox_title' => 'Horários' }) }
    let!(:handed_off) { bot_conversation(cached_label_list: 'horarios,vendas', custom_attributes: { 'sox_title' => 'Vendas' }) }
    let!(:taken_over) { bot_conversation }

    before do
      event('conversation_bot_resolved', resolved, value: 300)
      event('conversation_auto_resolved', abandoned)
      # handed off and later closed by inactivity: the handoff wins
      event('conversation_bot_handoff', handed_off, value: 120)
      event('conversation_opened', handed_off)
      event('conversation_auto_resolved', handed_off)
      event('conversation_opened', taken_over)
      create(:message, account: account, inbox: inbox, conversation: resolved, message_type: :outgoing, sender: agent_bot, created_at: 2.days.ago)
      create(:message, account: account, inbox: inbox, conversation: resolved, message_type: :outgoing, sender: agent_bot, created_at: 2.days.ago)
      create(:csat_survey_response, account: account, conversation: resolved, assigned_agent_bot: agent_bot, rating: 5, created_at: 1.day.ago)
      create(:csat_survey_response, account: account, conversation: resolved, assigned_agent_bot: agent_bot, rating: 2, created_at: 1.day.ago)
      # not the bot: another inbox, an agent's CSAT and an old bot conversation
      create(:conversation, account: account, inbox: other_inbox, created_at: 2.days.ago)
      create(:csat_survey_response, account: account, conversation: resolved, assigned_agent: create(:user, account: account), rating: 1)
      bot_conversation(created_at: 20.days.ago)
    end

    it 'describes the bot and its inboxes' do
      result = builder.build

      expect(result[:bots]).to match([hash_including(id: agent_bot.id, name: 'SuporteOficialX')])
      expect(result[:inboxes]).to eq([{ id: inbox.id, name: 'API' }])
      expect(result[:current]).to eq(pending_conversations: 5, unassigned_conversations: 0)
    end

    it 'counts each outcome once, with the handoff winning over inactivity' do
      summary = builder.build[:summary]

      expect(summary).to include(
        conversations_count: 4,
        outgoing_messages_count: 2,
        bot_resolved_count: 1,
        auto_resolved_count: 1,
        handoff_count: 1,
        taken_over_count: 1,
        avg_resolution_time: 300,
        avg_handoff_time: 120,
        csat_count: 2,
        csat_average: 3.5
      )
    end

    it 'compares against the previous period of the same length' do
      previous = builder.build[:previous_summary]

      expect(previous).to include(conversations_count: 0, bot_resolved_count: 0, csat_count: 0, csat_average: nil)
    end

    it 'returns one row per day and the weekday x hour activity' do
      result = builder.build

      expect(result[:daily].size).to eq(8)
      expect(result[:daily].sum { |day| day[:conversations_count] }).to eq(4)
      expect(result[:daily].sum { |day| day[:bot_resolved_count] }).to eq(1)
      expect(result[:daily].sum { |day| day[:auto_resolved_count] }).to eq(1)
      expect(result[:daily].sum { |day| day[:handoff_count] }).to eq(1)
      expect(result[:daily].sum { |day| day[:taken_over_count] }).to eq(1)
      expect(result[:hourly].sum { |cell| cell[:count] }).to eq(4)
    end

    it 'returns the CSAT of the bot, the labels, the subjects and where customers drop off' do
      result = builder.build

      expect(result[:csat][:ratings]).to include({ rating: 5, count: 1 }, { rating: 2, count: 1 })
      expect(result[:csat][:satisfaction_rate]).to eq(50.0)
      expect(result[:labels]).to eq([{ label: 'horarios', count: 2 }, { label: 'vendas', count: 1 }])
      expect(result[:titles]).to eq([{ label: 'Horários', count: 2 }, { label: 'Vendas', count: 1 }])
      expect(result[:abandoned_steps]).to eq([{ label: 'Menu: Horários', count: 1 }])
    end
  end

  context 'when no inbox has a bot' do
    let(:params) { { since: 7.days.ago.to_i.to_s, until: Time.current.to_i.to_s, timezone_offset: 0 } }

    before { AgentBotInbox.destroy_all }

    it 'returns empty figures' do
      result = builder.build

      expect(result[:bots]).to eq([])
      expect(result[:summary]).to include(conversations_count: 0, bot_resolved_count: 0, csat_average: nil)
      expect(result[:labels]).to eq([])
    end
  end
end
