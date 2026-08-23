module DashboardData
  extend ActiveSupport::Concern

  PT_MONTHS = %w[janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro].freeze

  private

  def load_dashboard_data
    @today = Date.current
    @setting = Setting.instance
    @current_balance = @setting.current_balance(as_of: @today)
    @projected_balance = @setting.projected_month_end_balance(as_of: @today)

    month_transactions = Transaction.where(date: @today.beginning_of_month..@today.end_of_month)
    @month_income_total = month_transactions.select(&:income?).sum(&:amount)
    @month_expense_total = month_transactions.select(&:expense?).sum(&:amount)

    @selected_month = params[:month].presence || current_month_value
    @month_options = build_month_options
    @transactions = filtered_transactions
  end

  def current_month_value
    @today.strftime("%Y-%m")
  end

  def build_month_options
    months_with_data = Transaction.distinct.pluck(:date).map { |date| date.strftime("%Y-%m") }
    all_months = (months_with_data + [ current_month_value ]).uniq.sort.reverse

    [ [ "Todos os meses", "all" ] ] + all_months.map { |month| [ month_label(month), month ] }
  end

  def month_label(month_value)
    year, month = month_value.split("-").map(&:to_i)
    "#{PT_MONTHS[month - 1].capitalize} de #{year}"
  end

  def filtered_transactions
    scope = Transaction.includes(:category).order(date: :desc)
    range = selected_month_range
    range ? scope.where(date: range) : scope
  end

  def selected_month_range
    return nil if @selected_month == "all"

    month = Date.strptime(@selected_month, "%Y-%m")
    month.beginning_of_month..month.end_of_month
  rescue ArgumentError, TypeError
    @today.beginning_of_month..@today.end_of_month
  end
end
