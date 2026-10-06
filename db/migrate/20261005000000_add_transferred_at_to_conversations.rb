class AddTransferredAtToConversations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :conversations, :transferred_at, :datetime
    add_index :conversations, [:account_id, :transferred_at], where: 'transferred_at IS NOT NULL', algorithm: :concurrently
  end
end
