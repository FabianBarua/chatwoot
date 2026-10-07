# One row per agent for the team ranking: the activity report figures (presence + conversations)
# plus CSAT and the conversations they have open right now.
#
# params: since, until (unix seconds), timezone_offset (hours)
class V2::Reports::AgentInsightsOverviewBuilder
  pattr_initialize [:account!, :params!]

  def build
    activity_rows.map do |row|
      row.except(:timeline, :daily).merge(
        csat_count: csat_counts[row[:id]].to_i,
        csat_average: csat_averages[row[:id]]&.to_f&.round(2),
        attended_conversations_count: attended_counts[row[:id]].to_i,
        open_conversations: open_counts[row[:id]].to_i,
        unattended_conversations: unattended_counts[row[:id]].to_i
      )
    end
  end

  private

  def activity_rows
    V2::Reports::AgentActivityBuilder.new(account: account, params: params.slice(:since, :until, :timezone_offset)).build
  end

  def range
    Time.zone.at(params[:since].to_i)..[Time.zone.at(params[:until].to_i), Time.current].min
  end

  def csat_scope
    account.csat_survey_responses.where(created_at: range).where.not(assigned_agent_id: nil).group(:assigned_agent_id)
  end

  def csat_counts
    @csat_counts ||= csat_scope.count
  end

  def csat_averages
    @csat_averages ||= csat_scope.average(:rating)
  end

  def attended_counts
    @attended_counts ||= account.messages.unscope(:order)
                                .where(created_at: range, message_type: :outgoing, private: false, sender_type: 'User')
                                .group(:sender_id).distinct.count(:conversation_id)
  end

  def open_conversations
    account.conversations.open.where.not(assignee_id: nil).group(:assignee_id)
  end

  def open_counts
    @open_counts ||= open_conversations.count
  end

  def unattended_counts
    @unattended_counts ||= open_conversations.unattended.count
  end
end
