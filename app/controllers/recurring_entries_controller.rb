class RecurringEntriesController < ApplicationController
  before_action :set_recurring_entry, only: %i[show edit update destroy]

  def index
    @recurring_entries = current_user.recurring_entries.includes(:category).order(:description)
  end

  def show; end

  def new
    @recurring_entry = current_user.recurring_entries.new(start_date: Date.current)
  end

  def edit; end

  def create
    @recurring_entry = current_user.recurring_entries.new(recurring_entry_params)
    if @recurring_entry.save
      RecurringEntryGenerator.call
      redirect_to recurring_entries_path, notice: "Recorrência criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @recurring_entry.update(recurring_entry_params)
      RecurringEntryGenerator.call
      redirect_to recurring_entries_path, notice: "Recorrência atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurring_entry.destroy
    redirect_to recurring_entries_path, notice: "Recorrência removida."
  end

  private

  def set_recurring_entry
    @recurring_entry = current_user.recurring_entries.find(params[:id])
  end

  def recurring_entry_params
    params.require(:recurring_entry).permit(:description, :amount, :kind, :day_of_month, :active, :start_date, :installments, :category_id)
  end
end
