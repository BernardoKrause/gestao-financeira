module DashboardData
  extend ActiveSupport::Concern

  private

  def load_dashboard_data
    @today = Date.current
    @setting = Setting.instance
    @current_balance = @setting.current_balance(as_of: @today)
    @projected_balance = @setting.projected_month_end_balance(as_of: @today)

    month_transactions = Transaction.where(date: @today.beginning_of_month..@today.end_of_month)
    @month_income_total = month_transactions.select(&:income?).sum(&:amount)
    @month_expense_total = month_transactions.select(&:expense?).sum(&:amount)

    @transactions = Transaction.includes(:category).order(date: :desc)
  end
end
