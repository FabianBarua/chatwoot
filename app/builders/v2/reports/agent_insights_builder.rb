# Supervisor dashboard for a single agent: KPIs against the previous period of the same length,
# daily series for the charts, when they work (weekday x hour), presence timeline, CSAT,
# and which labels and inboxes their conversations came from.
#
# params: since, until (unix seconds), timezone_offset (hours)
class V2::Reports::AgentInsightsBuilder
  pattr_initialize [:account!, :user!, :params!]

  TOP_LABELS_LIMIT = 8

  def build
    {
      agent: agent_payload,
      current: current_state,
      workload: V2::Reports::AgentWorkloadBuilder.new(account: account, user: user, range: range_start..range_end).build,
      summary: summary_for(range_start, range_end),
      previous_summary: summary_for(previous_start, range_start),
      daily: daily_series,
      hourly: hourly_activity,
      timeline: activity(range_start, range_end)[:timeline],
      csat: csat_breakdown,
      labels: top_labels,
      inboxes: inbox_breakdown
    }
  end

  private

  def range_start
    @range_start ||= Time.zone.at(params[:since].to_i)
  end

  # Never past "now", like the activity report
  def range_end
    @range_end ||= [Time.zone.at(params[:until].to_i), Time.current].min
  end

  def previous_start
    range_start - (Time.zone.at(params[:until].to_i) - range_start)
  end

  def timezone
    @timezone ||= ActiveSupport::TimeZone[params[:timezone_offset].to_f] || Time.zone
  end

  def account_user
    @account_user ||= account.account_users.find_by!(user_id: user.id)
  end

  def agent_payload
    {
      id: user.id,
      name: user.name,
      email: user.email,
      thumbnail: user.avatar_url,
      role: account_user.role,
      availability_status: account_user.availability_status
    }
  end

  def current_state
    open_conversations = account.conversations.open.assigned_to(user)
    {
      open_conversations: open_conversations.count,
      unattended_conversations: open_conversations.unattended.count
    }
  end

  def summary_for(from, to)
    conversation_summary(from, to).merge(message_summary(from, to), presence_summary(from, to), csat_summary(from, to))
  end

  def conversation_summary(from, to)
    metrics = conversation_metrics(from, to)
    {
      conversations_count: metrics[:conversations_count].to_i,
      resolved_conversations_count: metrics[:resolved_conversations_count].to_i,
      avg_first_response_time: metrics[:avg_first_response_time],
      avg_resolution_time: metrics[:avg_resolution_time],
      avg_reply_time: metrics[:avg_reply_time]
    }
  end

  def message_summary(from, to)
    messages = agent_messages(from, to)
    {
      attended_conversations_count: messages.where(private: false).distinct.count(:conversation_id),
      outgoing_messages_count: messages.where(private: false).count,
      private_notes_count: messages.where(private: true).count
    }
  end

  def presence_summary(from, to)
    presence = activity(from, to)
    {
      online_seconds: presence[:online_seconds].to_i,
      busy_seconds: presence[:busy_seconds].to_i,
      sessions_count: presence[:sessions_count].to_i
    }
  end

  def csat_summary(from, to)
    csat = csat_scope(from, to)
    { csat_count: csat.count, csat_average: csat.average(:rating)&.to_f&.round(2) }
  end

  def conversation_metrics(from, to)
    V2::Reports::AgentSummaryBuilder.new(
      account: account,
      params: { since: from.to_i.to_s, until: to.to_i.to_s, type: :agent, business_hours: false }
    ).build.find { |row| row[:id] == user.id } || {}
  end

  def activity(from, to)
    @activity ||= {}
    @activity[[from.to_i, to.to_i]] ||= V2::Reports::AgentActivityBuilder.new(
      account: account,
      params: { since: from.to_i.to_s, until: to.to_i.to_s, timezone_offset: params[:timezone_offset], user_id: user.id }
    ).build.first || {}
  end

  def agent_messages(from, to)
    account.messages.unscope(:order)
           .where(created_at: from..to, message_type: :outgoing, sender_type: 'User', sender_id: user.id)
  end

  def reporting_events(name)
    account.reporting_events.where(name: name, user_id: user.id, created_at: range_start..range_end)
  end

  def by_day(scope)
    scope.group_by_day(:created_at, time_zone: timezone, range: range_start..range_end)
  end

  def daily_series
    presence = (activity(range_start, range_end)[:daily] || []).index_by { |day| day[:date] }
    days.map { |date| daily_row(date, presence[date.to_s] || {}) }
  end

  def daily_row(date, presence)
    {
      date: date.to_s,
      outgoing_messages_count: daily_metrics[:sent][date].to_i,
      assigned_conversations_count: daily_metrics[:assigned][date].to_i,
      attended_conversations_count: daily_metrics[:attended][date].to_i,
      resolved_conversations_count: daily_metrics[:resolved][date].to_i,
      avg_first_response_time: daily_metrics[:first_response][date]&.to_f,
      online_seconds: presence[:online_seconds].to_i,
      busy_seconds: presence[:busy_seconds].to_i
    }
  end

  def daily_metrics
    @daily_metrics ||= begin
      messages = agent_messages(range_start, range_end).where(private: false)
      {
        assigned: by_day(account.conversations.where(assignee_id: user.id)).count,
        sent: by_day(messages).count,
        attended: by_day(messages).distinct.count(:conversation_id),
        resolved: by_day(reporting_events('conversation_resolved')).count,
        first_response: by_day(reporting_events('first_response')).average(:value)
      }
    end
  end

  def days
    (range_start.in_time_zone(timezone).to_date..range_end.in_time_zone(timezone).to_date).to_a
  end

  # Messages sent per weekday (0 = Sunday) and hour of the day, in the viewer's timezone
  def hourly_activity
    agent_messages(range_start, range_end).where(private: false)
                                          .group_by_day_of_week(:created_at, time_zone: timezone)
                                          .group_by_hour_of_day(:created_at, time_zone: timezone)
                                          .count
                                          .filter_map { |(weekday, hour), count| { weekday: weekday, hour: hour, count: count } if count.positive? }
  end

  def csat_scope(from, to)
    account.csat_survey_responses.where(assigned_agent_id: user.id, created_at: from..to)
  end

  def csat_breakdown
    ratings = csat_scope(range_start, range_end).group(:rating).count
    total = ratings.values.sum
    satisfied = ratings.select { |rating, _| rating >= 4 }.values.sum

    {
      ratings: (1..5).map { |rating| { rating: rating, count: ratings[rating] || 0 } },
      satisfaction_rate: total.positive? ? (satisfied * 100.0 / total).round(1) : nil
    }
  end

  # Conversations where the agent replied in the period
  def attended_conversations
    account.conversations.where(id: agent_messages(range_start, range_end).where(private: false).select(:conversation_id))
  end

  def top_labels
    attended_conversations.pluck(:cached_label_list)
                          .flat_map { |list| list.to_s.split(',').map(&:strip) }
                          .compact_blank
                          .tally
                          .sort_by { |label, count| [-count, label] }
                          .first(TOP_LABELS_LIMIT)
                          .map { |label, count| { label: label, count: count } }
  end

  def inbox_breakdown
    counts = attended_conversations.group(:inbox_id).count
    names = account.inboxes.where(id: counts.keys).pluck(:id, :name).to_h

    counts.sort_by { |_, count| -count }.map { |inbox_id, count| { id: inbox_id, name: names[inbox_id], count: count } }
  end
end
