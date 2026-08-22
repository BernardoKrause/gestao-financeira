require "rails_helper"

RSpec.describe "QuickEntries", type: :request do
  let(:user) { create(:user) }
  let(:expense_category) { create(:category, kind: :expense) }
  let(:income_category) { create(:category, kind: :income) }

  before { sign_in user }

  it "creates a one-off expense transaction and redirects to the dashboard" do
    expect {
      post quick_entries_path, params: { kind: "expense", description: "Mercado", amount: 150, date: Date.current, category_id: expense_category.id }
    }.to change(Transaction, :count).by(1)

    expect(response).to redirect_to(root_path)
    transaction = Transaction.last
    expect(transaction.kind).to eq("expense")
    expect(transaction.description).to eq("Mercado")
  end

  it "creates a one-off income transaction" do
    expect {
      post quick_entries_path, params: { kind: "income", description: "Freela", amount: 500, date: Date.current, category_id: income_category.id }
    }.to change(Transaction, :count).by(1)

    expect(Transaction.last.kind).to eq("income")
  end

  it "creates a fixed expense recurring entry and generates this month's transaction immediately" do
    expect {
      post quick_entries_path, params: { kind: "expense", fixed: "1", description: "Aluguel", amount: 1500, day_of_month: Date.current.day, category_id: expense_category.id }
    }.to change(RecurringEntry, :count).by(1)

    entry = RecurringEntry.last
    expect(entry.start_date).to eq(Date.current)
    expect(entry.end_date).to be_nil
    expect(entry.transactions.count).to eq(1)
    expect(response).to redirect_to(root_path)
  end

  it "creates an installment purchase with a computed end_date, stopping after the last installment" do
    post quick_entries_path, params: { kind: "expense", fixed: "1", description: "TV parcelada", amount: 300, day_of_month: Date.current.day, installments: 3, category_id: expense_category.id }

    entry = RecurringEntry.last
    expect(entry.end_date).to eq(Date.current + 2.months)

    # First installment generated immediately (today).
    expect(entry.transactions.count).to eq(1)

    # Still due next month and the month after (2nd and 3rd installments)...
    RecurringEntryGenerator.call(today: Date.current + 1.month)
    RecurringEntryGenerator.call(today: Date.current + 2.months)
    expect(entry.transactions.count).to eq(3)

    # ...but not a 4th, past end_date.
    RecurringEntryGenerator.call(today: Date.current + 3.months)
    expect(entry.transactions.count).to eq(3)
  end

  it "creates a fixed income recurring entry and generates this month's transaction immediately" do
    expect {
      post quick_entries_path, params: { kind: "income", fixed: "1", description: "Salário", amount: 5000, day_of_month: Date.current.day, category_id: income_category.id }
    }.to change(RecurringEntry, :count).by(1)

    entry = RecurringEntry.last
    expect(entry.kind).to eq("income")
    expect(entry.transactions.count).to eq(1)
    expect(response).to redirect_to(root_path)
  end

  it "does not create anything with an invalid amount, and re-renders the dashboard" do
    expect {
      post quick_entries_path, params: { kind: "expense", description: "Mercado", amount: 0, date: Date.current, category_id: expense_category.id }
    }.not_to change(Transaction, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "filters categories by kind in each quick entry form" do
    expense_cat = create(:category, name: "Mercado", kind: :expense)
    income_cat = create(:category, name: "Salário", kind: :income)

    get root_path

    body = response.body
    expense_form = body[/<details[^>]*quick-entry--expense.*?<\/details>/m]
    income_form = body[/<details[^>]*quick-entry--income.*?<\/details>/m]

    expect(expense_form).to include("Mercado")
    expect(expense_form).not_to include("Salário")
    expect(income_form).to include("Salário")
    expect(income_form).not_to include("Mercado")
  end

  it "reopens the expense form with the validation error after an invalid submission" do
    category = create(:category, kind: :expense)

    post quick_entries_path, params: { kind: "expense", description: "Mercado", amount: 0, date: Date.current, category_id: category.id }

    body = response.body
    expense_form = body[/<details[^>]*quick-entry--expense.*?<\/details>/m]

    expect(expense_form).to include("error-messages")
    expect(expense_form).to match(/<details open/)
  end

  it "keeps the expense form closed when an income submission fails validation" do
    category = create(:category, kind: :income)

    post quick_entries_path, params: { kind: "income", description: "Salário", amount: 0, date: Date.current, category_id: category.id }

    body = response.body
    expense_form = body[/<details[^>]*quick-entry--expense.*?<\/details>/m]

    expect(expense_form).not_to match(/<details open/)
    expect(expense_form).not_to include("error-messages")
  end
end
