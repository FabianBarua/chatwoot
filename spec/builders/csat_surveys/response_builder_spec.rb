require 'rails_helper'

describe CsatSurveys::ResponseBuilder do
  let(:message) do
    create(
      :message, content_type: :input_csat,
                content_attributes: { 'submitted_values': { 'csat_survey_response': { 'rating': 5, 'feedback_message': 'hello' } } }
    )
  end

  describe '#perform' do
    it 'creates a new csat survey response' do
      csat_survey_response = described_class.new(
        message: message
      ).perform

      expect(csat_survey_response.valid?).to be(true)
    end

    it 'keeps the agent bot when the conversation has no human assignee' do
      agent_bot = create(:agent_bot, account: message.account)
      message.conversation.update!(assignee: nil, ai_assignee: agent_bot)

      csat_survey_response = described_class.new(message: message).perform

      expect(csat_survey_response.assigned_agent).to be_nil
      expect(csat_survey_response.assigned_agent_bot).to eq(agent_bot)
    end

    it 'prefers the human assignee over the agent bot' do
      agent = create(:user, account: message.account)
      agent_bot = create(:agent_bot, account: message.account)
      message.conversation.update!(assignee: agent)
      message.conversation.update_columns(assignee_agent_bot_id: agent_bot.id, ai_assignee_type: 'AgentBot') # rubocop:disable Rails/SkipsModelValidations

      csat_survey_response = described_class.new(message: message).perform

      expect(csat_survey_response.assigned_agent).to eq(agent)
      expect(csat_survey_response.assigned_agent_bot).to be_nil
    end

    it 'updates the value of csat survey response if response already exists' do
      existing_survey_response = create(:csat_survey_response, message: message)
      csat_survey_response = described_class.new(
        message: message
      ).perform

      expect(csat_survey_response.id).to eq(existing_survey_response.id)
      expect(csat_survey_response.rating).to eq(5)
    end
  end
end
