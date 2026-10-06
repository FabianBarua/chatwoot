# == Schema Information
#
# Table name: canned_responses
#
#  id         :integer          not null, primary key
#  content    :text
#  short_code :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#

class CannedResponse < ApplicationRecord
  include AccountCacheRevalidator
  include Rails.application.routes.url_helpers

  validates :content, presence: true, unless: -> { files.attached? }
  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }

  belongs_to :account
  has_many_attached :files

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])
    content_like = sanitize_sql_array(['WHEN content ILIKE ? THEN 0.2', "%#{search}%"])

    order_clause = "CASE #{short_code_starts_with} #{short_code_like} #{content_like} ELSE 0 END"

    order(Arel.sql(order_clause) => :desc)
  }

  # Attached media sent along with the text when the shortcut is used from the reply box.
  # `signed_id` is what the message endpoint accepts in `attachments[]` to reuse the stored blob.
  def file_base_data
    files.map do |file|
      {
        id: file.id,
        blob_id: file.blob_id,
        signed_id: file.blob.signed_id,
        filename: file.filename.to_s,
        content_type: file.content_type,
        byte_size: file.byte_size,
        file_url: url_for(file)
      }
    end
  end
end
