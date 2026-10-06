# == Schema Information
#
# Table name: agent_availability_logs
#
#  id           :bigint           not null, primary key
#  availability :string           not null
#  created_at   :datetime         not null
#  account_id   :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_agent_availability_logs_on_account_id_and_created_at  (account_id,created_at)
#  index_agent_availability_logs_on_account_user_created       (account_id,user_id,created_at)
#

# One row per change of an agent's effective status (online / busy / offline), as the
# dashboard shows it: the agent's chosen availability combined with websocket presence.
class AgentAvailabilityLog < ApplicationRecord
  STATUSES = %w[online busy offline].freeze

  belongs_to :account
  belongs_to :user

  validates :availability, inclusion: { in: STATUSES }

  scope :before, ->(time) { where(created_at: ...time) }

  # Latest status per user, as { user_id => availability }
  def self.last_status_by_user(scope = all)
    scope.select('DISTINCT ON (user_id) user_id, availability')
         .order('user_id, created_at DESC')
         .to_h { |log| [log.user_id, log.availability] }
  end
end
