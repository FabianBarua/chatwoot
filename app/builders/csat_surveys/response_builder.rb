class CsatSurveys::ResponseBuilder
  pattr_initialize [:message]

  def perform
    raise 'Invalid Message' unless message.input_csat?

    conversation = message.conversation
    submitted = message.content_attributes.dig('submitted_values', 'csat_survey_response') || {}

    return if submitted['rating'].blank?

    process_csat_response(conversation, submitted)
  end

  private

  def process_csat_response(conversation, submitted)
    csat_survey_response = message.csat_survey_response || CsatSurveyResponse.new(
      message_id: message.id, account_id: message.account_id, conversation_id: message.conversation_id,
      contact_id: conversation.contact_id, assigned_agent: conversation.assignee, assigned_agent_bot: assigned_agent_bot(conversation)
    )
    csat_survey_response.rating = submitted['rating']
    csat_survey_response.feedback_message = submitted['feedback_message']
    # Xplus: the reason picked after a low rating; blank means the customer skipped it
    csat_survey_response.reason = submitted['reason'].presence
    csat_survey_response.save!
    csat_survey_response
  end

  # Xplus: a conversation the bot resolved has no human assignee but keeps the agent bot
  def assigned_agent_bot(conversation)
    return if conversation.assignee.present?

    conversation.ai_assignee if conversation.ai_assignee.is_a?(AgentBot)
  end
end
