# Xplus: quien acaba de quedar disponible recibe lo que estaba esperando.
# Chatwoot reparte una conversación solo cuando se abre (el bot la deriva) y solo entre los
# miembros de la bandeja online en ese segundo; si no había nadie, quedaba "no asignada" hasta
# otro movimiento de la bandeja (el job periódico solo cubre bandejas con política).
class AutoAssignment::AgentOnlineService
  pattr_initialize [:account!, :user!]

  def perform
    return unless account.feature_enabled?('assignment_v2')
    return unless ::OnlineStatusTracker.get_available_users(account.id)[user.id.to_s] == 'online'

    # Coalescido por bandeja (una claim en Redis por job en vuelo): los pings de presencia no encolan de más.
    user.inbox_members.joins(:inbox).where(inboxes: { account_id: account.id, enable_auto_assignment: true }).pluck(:inbox_id).each do |inbox_id|
      AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox_id)
    end
  end
end
