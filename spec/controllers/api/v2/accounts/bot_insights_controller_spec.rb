require 'rails_helper'

RSpec.describe 'Bot Insights API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:agent_bot) { create(:agent_bot, account: account, name: 'SuporteOficialX') }
  let(:inbox) { create(:inbox, account: account, name: 'API') }
  let(:params) { { since: 3.days.ago.beginning_of_day.to_i.to_s, until: Time.current.end_of_day.to_i.to_s, timezone_offset: 0 } }

  before do
    create(:agent_bot_inbox, agent_bot: agent_bot, inbox: inbox)
    conversation = create(:conversation, account: account, inbox: inbox, status: :pending, ai_assignee: agent_bot, cached_label_list: 'horarios')
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent_bot)
    create(:reporting_event, account: account, inbox: inbox, conversation: conversation, user: nil, name: 'conversation_bot_resolved', value: 60)
    create(:csat_survey_response, account: account, conversation: conversation, assigned_agent_bot: agent_bot, rating: 4)
  end

  describe 'GET /api/v2/accounts/:account_id/bot_insights' do
    it 'returns unauthorized for agents' do
      get "/api/v2/accounts/#{account.id}/bot_insights", params: params, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    context 'when an admin requests the report' do
      let(:body) { response.parsed_body }

      before do
        get "/api/v2/accounts/#{account.id}/bot_insights", params: params, headers: admin.create_new_auth_token, as: :json
      end

      it 'returns the bot and its current state' do
        expect(response).to have_http_status(:success)
        expect(body['bots']).to match([hash_including('id' => agent_bot.id, 'name' => 'SuporteOficialX')])
        expect(body['current']).to include('pending_conversations' => 1)
      end

      it 'returns the period summary and the previous period' do
        expect(body['summary']).to include(
          'conversations_count' => 1, 'outgoing_messages_count' => 1, 'bot_resolved_count' => 1, 'auto_resolved_count' => 0,
          'avg_resolution_time' => 60, 'csat_count' => 1, 'csat_average' => 4.0
        )
        expect(body['previous_summary']).to include('conversations_count' => 0)
      end

      it 'returns the daily series, the CSAT and the labels' do
        expect(body['daily'].size).to eq(4)
        expect(body['csat']['ratings']).to include({ 'rating' => 4, 'count' => 1 })
        expect(body['labels']).to eq([{ 'label' => 'horarios', 'count' => 1 }])
      end
    end
  end
end
