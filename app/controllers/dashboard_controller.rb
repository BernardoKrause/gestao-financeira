class DashboardController < ApplicationController
  include DashboardData

  def index
    load_dashboard_data
  end
end
