module AssignmentHandler
  extend ActiveSupport::Concern
  include Events::Types

  included do
    before_save :ensure_assignee_is_from_team
    before_save :track_transfer
    after_commit :notify_assignment_change, :process_assignment_changes
  end

  private

  # A transfer is an agent-to-agent handover. The conversation is flagged until the new
  # assignee replies, and is put back in the "waiting on agent" state so it shows up as unattended.
  def track_transfer
    return unless assignee_id_changed?

    if assignee_id.present? && assignee_id_was.present?
      self.transferred_at = Time.current
      self.waiting_since ||= Time.current
    elsif assignee_id.blank?
      self.transferred_at = nil
    end
  end

  def ensure_assignee_is_from_team
    return unless team_id_changed?
    return if ai_assignee_type.present?

    validate_current_assignee_team
    self.assignee ||= find_assignee_from_team
  end

  def validate_current_assignee_team
    self.assignee_id = nil if team&.members&.exclude?(assignee)
  end

  def find_assignee_from_team
    return if team&.allow_auto_assign.blank?

    team_members_with_capacity = inbox.member_ids_with_assignment_capacity & team.members.ids
    ::AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: team_members_with_capacity).find_assignee
  end

  def notify_assignment_change
    {
      ASSIGNEE_CHANGED => lambda {
        saved_change_to_assignee_id? || saved_change_to_assignee_agent_bot_id? || saved_change_to_ai_assignee_type?
      },
      TEAM_CHANGED => -> { saved_change_to_team_id? }
    }.each do |event, condition|
      condition.call && dispatcher_dispatch(event, previous_changes)
    end
  end

  def process_assignment_changes
    process_assignment_activities
  end

  def process_assignment_activities
    user_name = Current.user.name if Current.user.present?
    if saved_change_to_team_id?
      create_team_change_activity(user_name)
    elsif saved_change_to_assignee_id?
      create_assignee_change_activity(user_name)
    end
  end

  def self_assign?(assignee_id)
    assignee_id.present? && Current.user&.id == assignee_id
  end
end
