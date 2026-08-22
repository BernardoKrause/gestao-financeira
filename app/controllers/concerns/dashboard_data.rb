module DashboardData
  extend ActiveSupport::Concern

  private

  def load_dashboard_data
    @today = Date.current
    @accounts = Account.order(:name)
    @total_current_balance = @accounts.sum { |account| account.current_balance(as_of: @today) }
    @total_projected_balance = @accounts.sum { |account| account.projected_month_end_balance(as_of: @today) }
    @transactions = Transaction.includes(:account, :category)
                                .where(date: @today.beginning_of_month..@today.end_of_month)
                                .order(date: :desc)
    @month_income_total = @transactions.select(&:income?).sum(&:amount)
    @month_expense_total = @transactions.select(&:expense?).sum(&:amount)
  end
end
