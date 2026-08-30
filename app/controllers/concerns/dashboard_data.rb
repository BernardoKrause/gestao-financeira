module DashboardData
  extend ActiveSupport::Concern

  PT_MONTHS = %w[janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro].freeze

  private

  def load_dashboard_data
    @today = Date.current
    @setting = Setting.instance
    @current_balance = @setting.current_balance(as_of: @today)
    @receita_prevista = @setting.pending_recurring_income_total(as_of: @today)
    @despesa_prevista = @setting.pending_recurring_expense_total(as_of: @today)
    @projected_balance = @setting.projected_month_end_balance(as_of: @today)
    @financial_health_status = @setting.financial_health_status(as_of: @today)

    @selected_month = params[:month].presence || current_month_value
    @month_options = build_month_options
    @selected_month_label = @month_options.find { |_label, value| value == @selected_month }&.first

    @selected_category_id = params[:category_id].presence
    @category_options = Category.order(:name).pluck(:name, :id)

    # Resumo and Histórico both reflect the same selected period and category.
    @transactions = filtered_transactions
    @month_income_total = @transactions.select(&:income?).sum(&:amount)
    @month_expense_total = @transactions.select(&:expense?).sum(&:amount)
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
    scope = scope.where(date: range) if range
    scope = scope.where(category_id: @selected_category_id) if @selected_category_id
    scope
  end

  def selected_month_range
    return nil if @selected_month == "all"

    month = Date.strptime(@selected_month, "%Y-%m")
    month.beginning_of_month..month.end_of_month
  rescue ArgumentError, TypeError
    @today.beginning_of_month..@today.end_of_month
  end
end
