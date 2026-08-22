class SettingsController < ApplicationController
  include DashboardData

  def update
    setting = Setting.instance
    if setting.update(setting_params)
      redirect_to root_path, notice: "Saldo inicial atualizado."
    else
      load_dashboard_data
      @setting = setting
      render "dashboard/index", status: :unprocessable_entity
    end
  end

  private

  def setting_params
    params.require(:setting).permit(:initial_balance)
  end
end
