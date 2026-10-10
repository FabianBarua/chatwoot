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

puts "account=#{account.id} admin=#{admin.email} inbox=#{inbox.id} conversations=#{account.conversations.count}"
