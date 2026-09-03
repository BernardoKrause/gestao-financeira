class QuickEntriesController < ApplicationController
  include DashboardData

  def create
    @kind = params[:kind].presence_in(%w[expense income])

    if @kind.nil?
      render_dashboard_with_error(nil)
      return
    end

    if params[:fixed] == "1"
      create_recurring_entry
    else
      create_transaction
    end
  end

  private

  def create_transaction
    @transaction = Transaction.new(
      user: current_user,
      description: params[:description],
      amount: params[:amount],
      kind: @kind,
      date: params[:date],
      category_id: params[:category_id]
    )

    if @transaction.save
      redirect_to dashboard_path, notice: "Lançamento registrado."
    else
      render_dashboard_with_error(@transaction)
    end
  end

  def create_recurring_entry
    if params[:parcelado] == "1"
      start_date = safe_parse_date(params[:start_date])
      day_of_month = start_date&.day
      installments = params[:installments].presence
    else
      start_date = Date.current
      day_of_month = params[:day_of_month]
      installments = nil
    end

    @recurring_entry = RecurringEntry.new(
      user: current_user,
      description: params[:description],
      amount: params[:amount],
      kind: @kind,
      day_of_month: day_of_month,
      start_date: start_date,
      installments: installments,
      category_id: params[:category_id]
    )

    if @recurring_entry.save
      RecurringEntryGenerator.call(user: current_user)
      redirect_to dashboard_path, notice: "Recorrência criada."
    else
      render_dashboard_with_error(@recurring_entry)
    end
  end

  def safe_parse_date(value)
    Date.parse(value) if value.present?
  rescue ArgumentError, TypeError
    nil
  end

  def render_dashboard_with_error(record)
    load_dashboard_data
    @quick_entry_kind = @kind
    @quick_entry_record = record
    render "dashboard/index", status: :unprocessable_entity
  end
end
