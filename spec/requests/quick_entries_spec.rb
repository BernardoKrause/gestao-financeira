require "rails_helper"

RSpec.describe "QuickEntries", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account) }
  let(:expense_category) { create(:category, kind: :expense) }
  let(:income_category) { create(:category, kind: :income) }

  before { sign_in user }

  it "creates a one-off expense transaction and redirects to the dashboard" do
    expect {
      post quick_entries_path, params: { kind: "expense", description: "Mercado", amount: 150, date: Date.current, account_id: account.id, category_id: expense_category.id }
    }.to change(Transaction, :count).by(1)

    expect(response).to redirect_to(root_path)
    transaction = Transaction.last
    expect(transaction.kind).to eq("expense")
    expect(transaction.description).to eq("Mercado")
  end

  it "creates a one-off income transaction" do
    expect {
      post quick_entries_path, params: { kind: "income", description: "Freela", amount: 500, date: Date.current, account_id: account.id, category_id: income_category.id }
    }.to change(Transaction, :count).by(1)

    expect(Transaction.last.kind).to eq("income")
  end

  it "creates a fixed expense recurring entry and generates this month's transaction immediately" do
    expect {
      post quick_entries_path, params: { kind: "expense", fixed: "1", description: "Aluguel", amount: 1500, day_of_month: Date.current.day, account_id: account.id, category_id: expense_category.id }
    }.to change(RecurringEntry, :count).by(1)

    entry = RecurringEntry.last
    expect(entry.start_date).to eq(Date.current)
    expect(entry.transactions.count).to eq(1)
    expect(response).to redirect_to(root_path)
  end

  it "does not create anything with an invalid amount, and re-renders the dashboard" do
    expect {
      post quick_entries_path, params: { kind: "expense", description: "Mercado", amount: 0, date: Date.current, account_id: account.id, category_id: expense_category.id }
    }.not_to change(Transaction, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
