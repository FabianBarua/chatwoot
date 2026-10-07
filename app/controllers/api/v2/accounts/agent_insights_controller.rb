# Agents report: team ranking (index) and the dashboard of one agent (show).
class Api::V2::Accounts::AgentInsightsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    render json: V2::Reports::AgentInsightsOverviewBuilder.new(account: Current.account, params: report_params).build
  end

  def show
    user = Current.account.users.find(params[:id])
    render json: V2::Reports::AgentInsightsBuilder.new(account: Current.account, user: user, params: report_params).build
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def report_params
    params.permit(:since, :until, :timezone_offset).to_h.symbolize_keys
  end
end
