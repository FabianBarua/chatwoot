# Keeps AgentAvailabilityLog in sync with the status agents actually show in the dashboard.
#
# Presence lives only in Redis (last heartbeat + chosen availability), so there is no event
# for an agent going offline. `snapshot` is run every minute by Agents::AvailabilitySnapshotJob
# and writes a row for every agent whose effective status changed; `record` is called right
# away when an agent picks a status in the UI.
class Agents::AvailabilityLogService
  pattr_initialize [:account!]

  def snapshot
    available = OnlineStatusTracker.get_available_users(account.id)
    last_status = AgentAvailabilityLog.last_status_by_user(account.agent_availability_logs)
    now = Time.current

    rows = account.account_users.pluck(:user_id).filter_map do |user_id|
      status = available[user_id.to_s] || 'offline'
      next if last_status[user_id] == status

      { account_id: account.id, user_id: user_id, availability: status, created_at: now }
    end

    # Rows are plain status strings already restricted by the tracker; one statement per account per minute
    # rubocop:disable Rails/SkipsModelValidations
    AgentAvailabilityLog.insert_all(rows) if rows.any?
    # rubocop:enable Rails/SkipsModelValidations
  end

  def record(user_id, status)
    last_status = AgentAvailabilityLog.last_status_by_user(account.agent_availability_logs.where(user_id: user_id))
    return if last_status[user_id] == status

    account.agent_availability_logs.create!(user_id: user_id, availability: status)
  end
end
