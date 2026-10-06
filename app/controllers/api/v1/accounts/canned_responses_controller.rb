class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    @canned_responses = canned_responses.with_attached_files
  end

  def create
    @canned_response = Current.account.canned_responses.new(canned_response_params)
    @canned_response.save!
  end

  # New files are appended: assigning `files` on an existing record would replace the ones already attached.
  def update
    ActiveRecord::Base.transaction do
      remove_files
      @canned_response.files.attach(canned_response_params[:files]) if canned_response_params[:files].present?
      @canned_response.update!(canned_response_params.except(:files))
    end
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content, files: [])
  end

  # Attachments the user removed in the edit form. The blob is purged only if no
  # message still references it (ActiveStorage keeps shared blobs).
  def remove_files
    ids = Array(params.dig(:canned_response, :remove_file_ids)).map(&:to_i)
    return if ids.empty?

    @canned_response.files.where(id: ids).find_each(&:purge_later)
  end

  def canned_responses
    if params[:search]
      search = params[:search].delete("\0")
      Current.account.canned_responses
             .where('short_code ILIKE :search OR content ILIKE :search', search: "%#{search}%")
             .order_by_search(search)

    else
      Current.account.canned_responses
    end
  end
end
