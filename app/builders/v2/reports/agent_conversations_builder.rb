# Conversations an agent resolved in the period, each with the CSAT the customer left (if any),
# so a supervisor can see which conversations got which rating and which reason.
#
# params: since, until (unix seconds), page, rating (1..5 or "none"), reason (text or "none")
class V2::Reports::AgentConversationsBuilder
  pattr_initialize [:account!, :user!, :params!]

  PER_PAGE = 25
  NONE = 'none'.freeze

  def build
    scope = filtered_scope
    page = [params[:page].to_i, 1].max
    records = scope.order('resolved.resolved_at DESC').offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a

    {
      total_count: scope.except(:select).count(:all),
      page: page,
      per_page: PER_PAGE,
      records: records.map { |conversation| conversation_payload(conversation) }
    }
  end

  private

  def range
    Time.zone.at(params[:since].to_i)..Time.zone.at(params[:until].to_i)
  end

  # The last time the agent resolved each conversation in the period
  def resolved_sql
    account.reporting_events
           .where(name: 'conversation_resolved', user_id: user.id, created_at: range)
           .group(:conversation_id)
           .select('conversation_id, MAX(created_at) AS resolved_at')
           .to_sql
  end

  # The latest CSAT response of each conversation
  def csat_sql
    account.csat_survey_responses
           .select('DISTINCT ON (conversation_id) conversation_id, rating, reason, feedback_message, created_at')
           .order('conversation_id, created_at DESC')
           .to_sql
  end

  def base_scope
    account.conversations
           .joins("INNER JOIN (#{resolved_sql}) resolved ON resolved.conversation_id = conversations.id")
           .joins("LEFT JOIN (#{csat_sql}) csat ON csat.conversation_id = conversations.id")
           .includes(:contact, :inbox)
           .select('conversations.*', 'resolved.resolved_at', 'csat.rating AS csat_rating', 'csat.reason AS csat_reason',
                   'csat.feedback_message AS csat_feedback', 'csat.created_at AS csat_created_at')
  end

  def filtered_scope
    scope = base_scope
    scope = apply_rating(scope, params[:rating].to_s) if params[:rating].present?
    scope = apply_reason(scope, params[:reason].to_s) if params[:reason].present?
    scope
  end

  def apply_rating(scope, rating)
    return scope.where(csat: { rating: nil }) if rating == NONE

    scope.where(csat: { rating: rating.to_i })
  end

  def apply_reason(scope, reason)
    return scope.where('csat.rating IS NOT NULL AND csat.reason IS NULL') if reason == NONE

    scope.where(csat: { reason: reason })
  end

  def conversation_payload(conversation)
    {
      id: conversation.id,
      display_id: conversation.display_id,
      contact: { id: conversation.contact_id, name: conversation.contact&.name },
      inbox: { id: conversation.inbox_id, name: conversation.inbox&.name },
      labels: conversation.cached_label_list_array,
      resolved_at: conversation.resolved_at.to_i,
      csat: csat_payload(conversation)
    }
  end

  def csat_payload(conversation)
    return nil if conversation.csat_rating.nil?

    {
      rating: conversation.csat_rating,
      reason: conversation.csat_reason,
      feedback_message: conversation.csat_feedback,
      created_at: conversation.csat_created_at.to_i
    }
  end
end
