class CreateAgentAvailabilityLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_availability_logs do |t|
      t.references :account, null: false, index: false
      t.references :user, null: false, index: false
      t.string :availability, null: false
      t.datetime :created_at, null: false
    end

    add_index :agent_availability_logs, [:account_id, :user_id, :created_at], name: 'index_agent_availability_logs_on_account_user_created'
    add_index :agent_availability_logs, [:account_id, :created_at]
  end
end
