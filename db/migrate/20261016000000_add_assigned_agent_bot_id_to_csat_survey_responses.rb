# Xplus: a CSAT answer for a conversation the bot resolved (no human assignee) keeps the agent bot,
# so the CSAT report can be filtered by bot and the bot report can show its own CSAT.
class AddAssignedAgentBotIdToCsatSurveyResponses < ActiveRecord::Migration[7.1]
  def change
    add_column :csat_survey_responses, :assigned_agent_bot_id, :bigint
    add_index :csat_survey_responses, :assigned_agent_bot_id
  end
end
