# Supervisor dashboard for the agent bot (SuporteOficialX): what reached the bot, how it ended
# (resolved by the bot, handed to the team, taken over by an agent, closed by inactivity), when the
# customers write, the bot's CSAT, and the subjects, labels and steps where customers drop off.
# KPIs are compared against the previous period of the same length, like the agent report.
#
# params: since, until (unix seconds), timezone_offset (hours)
class V2::Reports::BotInsightsBuilder
  pattr_initialize [:account!, :params!]

  TOP_ITEMS_LIMIT = 8
  # Conversation attributes written by SuporteOficialX: the subject and the step the bot was on
  TITLE_ATTRIBUTE = 'sox_title'.freeze
  STEP_ATTRIBUTE = 'sox_step'.freeze

  # Outcomes read from reporting_events, counted per distinct conversation. conversation_opened is
  # pending -> open without the bot handing off, that is, an agent took the conversation over.
  OUTCOME_EVENTS = {
    bot_resolved: 'conversation_bot_resolved',
    auto_resolved: 'conversation_auto_resolved',
    handoff: 'conversation_bot_handoff',
    taken_over: 'conversation_opened'
  }.freeze

  def build
    {
      bots: bots_payload,
      inboxes: bot_inboxes.map { |inbox| { id: inbox.id, name: inbox.name } },
      current: current_state,
      summary: summary_for(range_start, range_end),
      previous_summary: summary_for(previous_start, range_start),
      daily: daily_series,
      hourly: hourly_activity,
      csat: csat_breakdown,
      labels: top_labels,
      titles: top_attribute_values(bot_conversations(range_start, range_end), TITLE_ATTRIBUTE),
      abandoned_steps: top_attribute_values(auto_resolved_conversations, STEP_ATTRIBUTE)
    }
  end

  private

  def range_start
    @range_start ||= Time.zone.at(params[:since].to_i)
  end

  # Never past "now", like the agent report
  def range_end
    @range_end ||= [Time.zone.at(params[:until].to_i), Time.current].min
  end

  def previous_start
    range_start - (Time.zone.at(params[:until].to_i) - range_start)
  end

  def timezone
    @timezone ||= ActiveSupport::TimeZone[params[:timezone_offset].to_f] || Time.zone
  end

  def bot_inboxes
    @bot_inboxes ||= account.inboxes.includes(:agent_bot_inbox).select(&:active_bot?)
  end

  def bot_inbox_ids
    @bot_inbox_ids ||= bot_inboxes.map(&:id)
  end

  def bots_payload
    bot_ids = bot_inboxes.filter_map { |inbox| inbox.agent_bot_inbox&.agent_bot_id }.uniq
    AgentBot.where(id: bot_ids).map { |bot| { id: bot.id, name: bot.name, thumbnail: bot.avatar_url } }
  end

  def current_state
    {
      pending_conversations: account.conversations.pending.where.not(assignee_agent_bot_id: nil).count,
      unassigned_conversations: account.conversations.open.unassigned.where(inbox_id: bot_inbox_ids).count
    }
  end

  def summary_for(from, to)
    csat = csat_scope(from, to)
    outcome_counts(from, to).merge(
      conversations_count: bot_conversations(from, to).count,
      outgoing_messages_count: bot_messages(from, to).count,
      avg_resolution_time: outcome_scope(:bot_resolved, from, to).average(:value)&.to_f&.round,
      avg_handoff_time: outcome_scope(:handoff, from, to).average(:value)&.to_f&.round,
      csat_count: csat.count,
      csat_average: csat.average(:rating)&.to_f&.round(2)
    )
  end

  def outcome_counts(from, to)
    OUTCOME_EVENTS.keys.to_h { |outcome| [:"#{outcome}_count", outcome_scope(outcome, from, to).distinct.count(:conversation_id)] }
  end

  # When the bot handed the conversation off in the period, the handoff wins over any other outcome,
  # as in V2::Reports::BotMetricsBuilder
  def outcome_scope(outcome, from, to)
    scope = events(OUTCOME_EVENTS.fetch(outcome), from, to)
    return scope if outcome == :handoff

    handoffs = events(OUTCOME_EVENTS[:handoff], from, to).where.not(conversation_id: nil).select(:conversation_id)
    scope.where.not(conversation_id: handoffs)
  end

  def events(name, from, to)
    account.reporting_events.where(name: name, inbox_id: bot_inbox_ids, created_at: from..to)
  end

  def bot_conversations(from, to)
    account.conversations.where(inbox_id: bot_inbox_ids, created_at: from..to)
  end

  def bot_messages(from, to)
    account.messages.unscope(:order).where(sender_type: 'AgentBot', message_type: :outgoing, created_at: from..to)
  end

  def by_day(scope)
    scope.group_by_day(:created_at, time_zone: timezone, range: range_start..range_end)
  end

  def daily_series
    days.map { |date| { date: date.to_s }.merge(daily_metrics.transform_values { |counts| counts[date].to_i }) }
  end

  def daily_metrics
    @daily_metrics ||= {
      conversations_count: by_day(bot_conversations(range_start, range_end)).count,
      outgoing_messages_count: by_day(bot_messages(range_start, range_end)).count
    }.merge(daily_outcomes)
  end

  def daily_outcomes
    OUTCOME_EVENTS.keys.to_h do |outcome|
      [:"#{outcome}_count", by_day(outcome_scope(outcome, range_start, range_end)).distinct.count(:conversation_id)]
    end
  end

  def days
    (range_start.in_time_zone(timezone).to_date..range_end.in_time_zone(timezone).to_date).to_a
  end

  # Conversations that reached the bot per weekday (0 = Sunday) and hour, in the viewer's timezone
  def hourly_activity
    bot_conversations(range_start, range_end)
      .group_by_day_of_week(:created_at, time_zone: timezone)
      .group_by_hour_of_day(:created_at, time_zone: timezone)
      .count
      .filter_map { |(weekday, hour), count| { weekday: weekday, hour: hour, count: count } if count.positive? }
  end

  def csat_scope(from, to)
    account.csat_survey_responses.where.not(assigned_agent_bot_id: nil).where(created_at: from..to)
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

  def top_labels
    bot_conversations(range_start, range_end).pluck(:cached_label_list)
                                             .flat_map { |list| list.to_s.split(',').map(&:strip) }
                                             .compact_blank
                                             .tally
                                             .sort_by { |label, count| [-count, label] }
                                             .first(TOP_ITEMS_LIMIT)
                                             .map { |label, count| { label: label, count: count } }
  end

  def auto_resolved_conversations
    account.conversations.where(id: outcome_scope(:auto_resolved, range_start, range_end).select(:conversation_id))
  end

  def top_attribute_values(scope, attribute)
    scope.where('jsonb_exists(custom_attributes, :key)', key: attribute)
         .group(Arel.sql("custom_attributes->>'#{attribute}'"))
         .count
         .reject { |value, _| value.blank? }
         .sort_by { |value, count| [-count, value] }
         .first(TOP_ITEMS_LIMIT)
         .map { |value, count| { label: value, count: count } }
  end
end
