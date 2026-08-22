class RecurringEntriesController < ApplicationController
  before_action :set_recurring_entry, only: %i[show edit update destroy]

  def index
    @recurring_entries = RecurringEntry.includes(:category).order(:description)
  end

  def show; end

  def new
    @recurring_entry = RecurringEntry.new(start_date: Date.current)
  end

  def edit; end

  def create
    @recurring_entry = RecurringEntry.new(recurring_entry_params)
    if @recurring_entry.save
      redirect_to recurring_entries_path, notice: "Recorrência criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @recurring_entry.update(recurring_entry_params)
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
    @recurring_entry = RecurringEntry.find(params[:id])
  end

  def recurring_entry_params
    params.require(:recurring_entry).permit(:description, :amount, :kind, :day_of_month, :active, :start_date, :end_date, :category_id)
  end
end
