class AddReasonToCsatSurveyResponses < ActiveRecord::Migration[7.1]
  def change
    add_column :csat_survey_responses, :reason, :string
  end
end
