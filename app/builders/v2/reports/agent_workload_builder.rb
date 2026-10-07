# Where an agent's conversations stand: those assigned to them in the period plus any still active,
# split by current status.
#   attended = the agent replied to it in the period
#   waiting  = open and the customer is waiting for a reply
class V2::Reports::AgentWorkloadBuilder
  pattr_initialize [:account!, :user!, :range!]

  ACTIVE_STATUSES = %i[open pending snoozed].freeze

  def build
    by_status = cohort.group(:status).count

    {
      assigned: by_status.values.sum,
      resolved: by_status['resolved'].to_i,
      open: by_status['open'].to_i,
      pending: by_status['pending'].to_i,
      snoozed: by_status['snoozed'].to_i,
      attended: cohort.where(id: replied_conversation_ids).count,
      waiting: cohort.open.unattended.count
    }
  end

  private

  def assigned
    account.conversations.where(assignee_id: user.id)
  end

  def cohort
    assigned.where(created_at: range).or(assigned.where(status: ACTIVE_STATUSES))
  end

  def replied_conversation_ids
    account.messages.unscope(:order)
           .where(created_at: range, message_type: :outgoing, private: false, sender_type: 'User', sender_id: user.id)
           .select(:conversation_id)
  end
end
