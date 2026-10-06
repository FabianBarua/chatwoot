# Supervisor view: online / busy time, status changes and conversation metrics per agent.
# JSON for the dashboard page, CSV (`.csv`) for the download button.
class Api::V2::Accounts::AgentActivityReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @report_data = V2::Reports::AgentActivityBuilder.new(account: Current.account, params: report_params).build
    @timezone = ActiveSupport::TimeZone[params[:timezone_offset].to_f] || Time.zone

    if params[:format] == 'csv'
      response.headers['Content-Type'] = 'text/csv'
      response.headers['Content-Disposition'] = 'attachment; filename=agent_activity_report.csv'
      render layout: false, template: 'api/v2/accounts/agent_activity_reports/index', formats: [:csv]
    else
      render json: @report_data
    end
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def report_params
    params.permit(:since, :until, :timezone_offset, :user_id).to_h.symbolize_keys
  end
end
