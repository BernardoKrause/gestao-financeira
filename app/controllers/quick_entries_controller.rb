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
      description: params[:description],
      amount: params[:amount],
      kind: @kind,
      date: params[:date],
      category_id: params[:category_id]
    )

    if @transaction.save
      redirect_to root_path, notice: "Lançamento registrado."
    else
      render_dashboard_with_error(@transaction)
    end
  end

  def create_recurring_entry
    @recurring_entry = RecurringEntry.new(
      description: params[:description],
      amount: params[:amount],
      kind: @kind,
      day_of_month: params[:day_of_month],
      start_date: Date.current,
      end_date: installments_end_date,
      category_id: params[:category_id]
    )

    if @recurring_entry.save
      RecurringEntryGenerator.call
      redirect_to root_path, notice: "Recorrência criada."
    else
      render_dashboard_with_error(@recurring_entry)
    end
  end

  def installments_end_date
    installments = params[:installments].presence&.to_i
    return nil unless installments && installments > 1

    Date.current + (installments - 1).months
  end

  def render_dashboard_with_error(record)
    load_dashboard_data
    @quick_entry_kind = @kind
    @quick_entry_record = record
    render "dashboard/index", status: :unprocessable_entity
  end
end
