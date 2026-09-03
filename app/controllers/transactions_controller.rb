class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[show edit update destroy]

  def index
    @transactions = current_user.transactions.includes(:category).order(date: :desc)
  end

  def show; end

  def new
    @transaction = current_user.transactions.new(date: Date.current)
  end

  def edit; end

  def create
    @transaction = current_user.transactions.new(transaction_params)
    if @transaction.save
      redirect_to transactions_path, notice: "Lançamento criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to transactions_path, notice: "Lançamento atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_path, notice: "Lançamento removido."
  end

  private

  def set_transaction
    @transaction = current_user.transactions.find(params[:id])
  end

  def transaction_params
    params.require(:transaction).permit(:description, :amount, :kind, :date, :category_id)
  end
end
