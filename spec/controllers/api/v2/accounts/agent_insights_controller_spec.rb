require 'rails_helper'

RSpec.describe 'Agent Insights API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'Admin') }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp') }
  let(:params) { { since: 3.days.ago.beginning_of_day.to_i.to_s, until: Time.current.end_of_day.to_i.to_s, timezone_offset: 0 } }

  before do
    conversation = create(:conversation, account: account, inbox: inbox, assignee: agent, cached_label_list: 'ativacao,suporte')
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent, private: true)
    create(:reporting_event, account: account, inbox: inbox, conversation: conversation, user: agent, name: 'conversation_resolved')
    create(:reporting_event, account: account, inbox: inbox, conversation: conversation, user: agent, name: 'first_response', value: 120)
    create(:csat_survey_response, account: account, conversation: conversation, assigned_agent: agent, rating: 5)
    create(:csat_survey_response, account: account, conversation: conversation, assigned_agent: agent, rating: 3)
    create(:conversation, account: account, inbox: inbox, assignee: agent, status: :resolved)
  end

  describe 'GET /api/v2/accounts/:account_id/agent_insights' do
    it 'returns unauthorized for agents' do
      get "/api/v2/accounts/#{account.id}/agent_insights", params: params, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns one row per agent with conversation, presence and CSAT figures' do
      get "/api/v2/accounts/#{account.id}/agent_insights", params: params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      row = response.parsed_body.find { |item| item['id'] == agent.id }
      expect(row).to include(
        'outgoing_messages_count' => 2,
        'attended_conversations_count' => 1,
        'open_conversations' => 1,
        'csat_count' => 2,
        'csat_average' => 4.0
      )
      expect(row).not_to have_key('timeline')
    end
  end

  describe 'GET /api/v2/accounts/:account_id/agent_insights/:id' do
    it 'returns unauthorized for agents' do
      get "/api/v2/accounts/#{account.id}/agent_insights/#{agent.id}", params: params, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 404 for a user outside the account' do
      other = create(:user)

      get "/api/v2/accounts/#{account.id}/agent_insights/#{other.id}", params: params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    context 'when an admin requests an agent' do
      let(:body) { response.parsed_body }

      before do
        get "/api/v2/accounts/#{account.id}/agent_insights/#{agent.id}", params: params, headers: admin.create_new_auth_token, as: :json
      end

      it 'returns the agent and their current workload' do
        expect(response).to have_http_status(:success)
        expect(body['agent']).to include('id' => agent.id, 'name' => 'Ana', 'role' => 'agent')
        expect(body['current']).to include('open_conversations' => 1)
      end

      it 'returns the workload: assigned, resolved and still in attention' do
        expect(body['workload']).to include('assigned' => 2, 'resolved' => 1, 'open' => 1, 'pending' => 0, 'attended' => 1, 'waiting' => 0)
        expect(body['daily'].sum { |day| day['assigned_conversations_count'] }).to eq(2)
      end

      it 'returns the period summary and the previous period' do
        expect(body['summary']).to include(
          'outgoing_messages_count' => 2,
          'private_notes_count' => 1,
          'attended_conversations_count' => 1,
          'resolved_conversations_count' => 1,
          'csat_count' => 2,
          'csat_average' => 4.0
        )
        expect(body['previous_summary']).to include('outgoing_messages_count' => 0)
      end

      it 'returns one point per day and the weekday x hour activity' do
        expect(body['daily'].size).to eq(4)
        expect(body['daily'].sum { |day| day['outgoing_messages_count'] }).to eq(2)
        expect(body['daily'].sum { |day| day['resolved_conversations_count'] }).to eq(1)
        expect(body['hourly'].sum { |cell| cell['count'] }).to eq(2)
      end

      it 'returns CSAT, labels and inboxes' do
        expect(body['csat']['ratings']).to include({ 'rating' => 5, 'count' => 1 }, { 'rating' => 3, 'count' => 1 })
        expect(body['csat']['satisfaction_rate']).to eq(50.0)
        expect(body['labels']).to contain_exactly({ 'label' => 'ativacao', 'count' => 1 }, { 'label' => 'suporte', 'count' => 1 })
        expect(body['inboxes']).to eq([{ 'id' => inbox.id, 'name' => 'WhatsApp', 'count' => 1 }])
      end
    end
  end
end
