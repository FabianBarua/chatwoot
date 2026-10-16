# Bot report: the dashboard of the agent bot(s) of the account, same shape as the agent report.
class Api::V2::Accounts::BotInsightsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    render json: V2::Reports::BotInsightsBuilder.new(account: Current.account, params: report_params).build
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def report_params
    params.permit(:since, :until, :timezone_offset).to_h.symbolize_keys
  end
end
