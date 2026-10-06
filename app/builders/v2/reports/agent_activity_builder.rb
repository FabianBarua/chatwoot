# Supervisor report: how long each agent was online / busy in the period, their status
# changes, and their conversation metrics for the same range.
#
# params: since, until (unix seconds), timezone_offset (hours), user_id (optional)
class V2::Reports::AgentActivityBuilder
  pattr_initialize [:account!, :params!]

  ACTIVE_STATUSES = %w[online busy].freeze

  def build
    account_users.map do |account_user|
      build_row(account_user)
    end
  end

  private

  def account_users
    scope = account.account_users.includes(user: { avatar_attachment: :blob }).order(:id)
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
    scope
  end

  def range_start
    @range_start ||= Time.zone.at(params[:since].to_i)
  end

  # The report never extends into the future: an agent online right now is online "until now".
  def range_end
    @range_end ||= [Time.zone.at(params[:until].to_i), Time.current].min
  end

  def timezone
    @timezone ||= ActiveSupport::TimeZone[params[:timezone_offset].to_f] || Time.zone
  end

  def logs
    @logs ||= account.agent_availability_logs
                     .where(created_at: range_start..range_end)
                     .order(:created_at)
                     .group_by(&:user_id)
  end

  # Status each agent had when the period started
  def initial_status
    @initial_status ||= AgentAvailabilityLog.last_status_by_user(account.agent_availability_logs.before(range_start))
  end

  def summary_metrics
    @summary_metrics ||= V2::Reports::AgentSummaryBuilder.new(
      account: account,
      params: { since: params[:since], until: params[:until], type: :agent, business_hours: false }
    ).build.index_by { |row| row[:id] }
  end

  def outgoing_messages_count
    @outgoing_messages_count ||= account.messages
                                        .where(created_at: range_start..range_end, message_type: :outgoing, private: false, sender_type: 'User')
                                        .unscope(:order).group(:sender_id).count
  end

  def build_row(account_user)
    user = account_user.user

    {
      id: user.id,
      name: user.name,
      email: user.email,
      thumbnail: user.avatar_url,
      current_status: account_user.availability_status
    }.merge(presence_stats(user.id)).merge(conversation_stats(user.id))
  end

  def presence_stats(user_id)
    segments = segments_for(user_id)

    {
      online_seconds: seconds_in(segments, 'online'),
      busy_seconds: seconds_in(segments, 'busy'),
      sessions_count: sessions_count(user_id),
      first_online_at: segments.find { |s| ACTIVE_STATUSES.include?(s[:status]) }&.dig(:from),
      last_offline_at: last_offline_at(user_id),
      daily: daily_breakdown(segments),
      timeline: segments
    }
  end

  def conversation_stats(user_id)
    metrics = summary_metrics[user_id] || {}

    {
      conversations_count: metrics[:conversations_count] || 0,
      resolved_conversations_count: metrics[:resolved_conversations_count] || 0,
      avg_first_response_time: metrics[:avg_first_response_time],
      avg_resolution_time: metrics[:avg_resolution_time],
      avg_reply_time: metrics[:avg_reply_time],
      outgoing_messages_count: outgoing_messages_count[user_id] || 0
    }
  end

  # Continuous status intervals covering the whole period, clamped to [range_start, range_end]
  def segments_for(user_id)
    status = initial_status[user_id] || 'offline'
    cursor = range_start
    segments = []

    (logs[user_id] || []).each do |log|
      segments << segment(status, cursor, log.created_at) if log.created_at > cursor
      status = log.availability
      cursor = log.created_at
    end
    segments << segment(status, cursor, range_end) if range_end > cursor
    segments
  end

  def segment(status, from, to)
    { status: status, from: from.to_i, to: to.to_i, duration: (to - from).to_i }
  end

  def seconds_in(segments, status)
    segments.select { |s| s[:status] == status }.sum { |s| s[:duration] }
  end

  # A session starts whenever the agent goes from offline to online or busy
  def sessions_count(user_id)
    previous = initial_status[user_id] || 'offline'
    (logs[user_id] || []).count do |log|
      started = previous == 'offline' && ACTIVE_STATUSES.include?(log.availability)
      previous = log.availability
      started
    end
  end

  def last_offline_at(user_id)
    (logs[user_id] || []).reverse.find { |log| log.availability == 'offline' }&.created_at&.to_i
  end

  # Online / busy seconds per calendar day in the viewer's timezone
  def daily_breakdown(segments)
    days = Hash.new { |hash, date| hash[date] = { date: date, online_seconds: 0, busy_seconds: 0 } }

    segments.each do |seg|
      add_segment_to_days(days, seg) if ACTIVE_STATUSES.include?(seg[:status])
    end

    days.values
  end

  # A segment can span midnight, so it is split at each day boundary
  def add_segment_to_days(days, seg)
    key = :"#{seg[:status]}_seconds"
    cursor = Time.zone.at(seg[:from]).in_time_zone(timezone)
    finish = Time.zone.at(seg[:to]).in_time_zone(timezone)

    while cursor < finish
      day_end = [cursor.end_of_day, finish].min
      days[cursor.to_date.to_s][key] += (day_end - cursor).to_i
      cursor = day_end + 1.second
    end
  end
end
