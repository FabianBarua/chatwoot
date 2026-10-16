# Seeds the local verification stack: same admin credentials as db/seeds.rb (john@acme.inc),
# one account, two extra agents, a website inbox and a few conversations in different states.
GlobalConfig.clear_cache
ConfigLoader.new.process
Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)

account = Account.find_or_create_by!(name: 'Xplus Local')

admin = User.find_by(email: 'john@acme.inc')
unless admin
  admin = User.new(name: 'John', email: 'john@acme.inc', password: 'Password1!', type: 'SuperAdmin')
  admin.skip_confirmation!
  admin.save!
end
AccountUser.find_or_create_by!(account: account, user: admin) { |au| au.role = :administrator }

agents = %w[Ana Beto].map do |name|
  user = User.find_by(email: "#{name.downcase}@acme.inc")
  unless user
    user = User.new(name: name, email: "#{name.downcase}@acme.inc", password: 'Password1!')
    user.skip_confirmation!
    user.save!
  end
  AccountUser.find_or_create_by!(account: account, user: user) { |au| au.role = :agent }
  user
end

inbox = account.inboxes.find_by(name: 'Sitio web') ||
        Inbox.create!(account: account, name: 'Sitio web', channel: Channel::WebWidget.create!(account: account, website_url: 'https://xplus.test'))
([admin] + agents).each { |u| InboxMember.find_or_create_by!(inbox: inbox, user: u) }

def conversation_for(account, inbox, name, assignee: nil)
  contact = account.contacts.find_by(name: name) || Contact.create!(account: account, name: name, email: "#{name.parameterize}@cliente.test")
  ci = ContactInbox.find_or_create_by!(contact: contact, inbox: inbox) { |c| c.source_id = SecureRandom.uuid }
  conv = account.conversations.find_by(contact_inbox: ci)
  return conv if conv

  conv = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci, assignee: assignee)
  conv.messages.create!(account: account, inbox: inbox, message_type: :incoming, content: "Hola, soy #{name}", sender: contact)
  conv
end

# 1. unattended + mine: assigned to admin, customer waiting
conversation_for(account, inbox, 'Carlos Espera', assignee: admin)

# 2. attended: admin already replied
c2 = conversation_for(account, inbox, 'Lucía Atendida', assignee: admin)
c2.messages.create!(account: account, inbox: inbox, message_type: :outgoing, content: 'Hola Lucía, ¿en qué te ayudo?', sender: admin) if c2.messages.outgoing.empty?

# 3. transferred: Ana replied, then handed over to admin
c3 = conversation_for(account, inbox, 'Pedro Transferido', assignee: agents.first)
if c3.messages.outgoing.empty?
  c3.messages.create!(account: account, inbox: inbox, message_type: :outgoing, content: 'Hola Pedro, soy Ana', sender: agents.first)
  Current.user = agents.first
  c3.reload.update!(assignee: admin)
  Current.reset
end

# 4. unassigned
conversation_for(account, inbox, 'María Sin Asignar')

# 5. handled by a bot: pending, assigned to an agent bot, with the step it is on
bot = account.agent_bots.find_by(name: 'SuporteOficialX') || account.agent_bots.create!(name: 'SuporteOficialX', description: 'Bot de prueba')
c5 = conversation_for(account, inbox, 'Rosa Con Bot')
unless c5.pending?
  c5.update!(status: :pending, ai_assignee: bot, custom_attributes: { 'sox_step' => 'Menu: Horários', 'sox_flow' => 'Clínica v1' })
  c5.messages.create!(account: account, inbox: inbox, message_type: :outgoing, content: 'Olá! Como posso ajudar?', sender: bot)
end

# some availability history for the report
log = account.agent_availability_logs
if log.empty?
  now = Time.current
  log.create!(user: agents.first, availability: 'online', created_at: now - 5.hours)
  log.create!(user: agents.first, availability: 'busy', created_at: now - 3.hours)
  log.create!(user: agents.first, availability: 'offline', created_at: now - 2.hours)
  log.create!(user: agents.last, availability: 'online', created_at: now - 26.hours)
  log.create!(user: agents.last, availability: 'offline', created_at: now - 20.hours)
  log.create!(user: agents.last, availability: 'online', created_at: now - 4.hours)
end

# 6. the bot's own API inbox (like SuporteOficialX in production) with conversations that already
# ended, each with the reporting event the bot report reads. Status is set without callbacks so
# the events are exactly these.
bot_inbox = account.inboxes.find_by(name: 'SuporteOficialX') ||
            Inbox.create!(account: account, name: 'SuporteOficialX', channel: Channel::Api.create!(account: account))
AgentBotInbox.find_or_create_by!(inbox: bot_inbox, agent_bot: bot) { |abi| abi.status = :active }
([admin] + agents).each { |u| InboxMember.find_or_create_by!(inbox: bot_inbox, user: u) }

def bot_event(conversation, name, seconds)
  conversation.account.reporting_events.create!(
    name: name, value: seconds, value_in_business_hours: 0, inbox_id: conversation.inbox_id, conversation_id: conversation.id,
    event_start_time: conversation.created_at, event_end_time: conversation.created_at + seconds, created_at: conversation.created_at + seconds
  )
end

bot_outcomes = [
  { name: 'Sofía Resuelta', days_ago: 1, attributes: { 'sox_title' => 'Horários', 'sox_step' => 'Fim' }, labels: 'horarios',
    events: [['conversation_bot_resolved', 240]], status: :resolved, csat: 5 },
  { name: 'Diego Inactivo', days_ago: 2, attributes: { 'sox_title' => 'Horários', 'sox_step' => 'Menu: Horários' }, labels: 'horarios',
    events: [['conversation_auto_resolved', 7200]], status: :resolved },
  { name: 'Marta Derivada', days_ago: 2, attributes: { 'sox_title' => 'Vendas', 'sox_step' => 'Equipe' }, labels: 'vendas',
    events: [['conversation_opened', 180], ['conversation_bot_handoff', 180]], status: :open },
  { name: 'Hugo Asumido', days_ago: 3, attributes: { 'sox_title' => 'Vendas', 'sox_step' => 'Menu: Início' }, labels: 'vendas',
    events: [['conversation_opened', 600]], status: :open, assignee: true }
]
bot_outcomes.each do |outcome|
  conv = conversation_for(account, bot_inbox, outcome[:name])
  next if conv.reporting_events.exists?

  started_at = outcome[:days_ago].days.ago
  # rubocop:disable Rails/SkipsModelValidations
  conv.update_columns(created_at: started_at, custom_attributes: outcome[:attributes], cached_label_list: outcome[:labels])
  conv.messages.create!(account: account, inbox: bot_inbox, message_type: :outgoing, sender: bot, created_at: started_at + 5,
                        content: "Olá #{outcome[:name].split.first}! Como posso ajudar?")
  outcome[:events].each { |event_name, seconds| bot_event(conv.reload, event_name, seconds) }
  columns = { status: Conversation.statuses[outcome[:status]] }
  if outcome[:status] == :open
    columns[:assignee_agent_bot_id] = nil
    columns[:ai_assignee_type] = nil
  end
  columns[:assignee_id] = agents.first.id if outcome[:assignee]
  conv.update_columns(columns)
  # rubocop:enable Rails/SkipsModelValidations

  next unless outcome[:csat]

  csat_message = conv.messages.create!(account: account, inbox: bot_inbox, message_type: :template, content_type: :input_csat,
                                       content: 'Avalie o atendimento', created_at: started_at + 300)
  CsatSurveyResponse.create!(account: account, conversation: conv, message: csat_message, contact: conv.contact, rating: outcome[:csat],
                             feedback_message: 'Rápido e claro', assigned_agent_bot: bot, created_at: started_at + 600)
end

puts "account=#{account.id} admin=#{admin.email} inbox=#{inbox.id} bot_inbox=#{bot_inbox.id} conversations=#{account.conversations.count}"
