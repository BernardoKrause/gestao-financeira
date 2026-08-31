class DashboardController < ApplicationController
  include DashboardData

  def index
    load_dashboard_data
  end

  def update_view
    load_dashboard_data

    confidence = params[:confidence].presence_in(Setting::CONFIDENCE_LEVELS.map(&:to_s)) || "recurring"
    @confidence = confidence.to_sym
    @projected_balance = @setting.projected_balance_for(confidence: @confidence, as_of: @today)
    @financial_health_status = @setting.financial_health_status_for(confidence: @confidence, as_of: @today)

    respond_to(&:turbo_stream)
  end
end
