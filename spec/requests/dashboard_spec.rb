require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "shows the current balance and, by default, only this month's history" do
    Setting.instance.update!(initial_balance: 1000)
    category = create(:category)
    create(:transaction, category: category, description: "Mercado", amount: 100, kind: :expense, date: Date.current)
    create(:transaction, category: category, description: "Aluguel atrasado", amount: 50, kind: :expense, date: 3.months.ago.to_date)

    get root_path

    expect(response).to have_http_status(:ok)
    # current_balance is accumulated (unaffected by the history filter)
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(850, unit: "R$ "))
    expect(response.body).to include("Mercado")
    expect(response.body).not_to include("Aluguel atrasado")
  end

  it "shows the full history when the 'all months' filter is selected" do
    category = create(:category)
    create(:transaction, category: category, description: "Mercado", amount: 100, kind: :expense, date: Date.current)
    create(:transaction, category: category, description: "Aluguel atrasado", amount: 50, kind: :expense, date: 3.months.ago.to_date)

    get root_path, params: { month: "all" }

    expect(response.body).to include("Mercado")
    expect(response.body).to include("Aluguel atrasado")
  end

  it "shows only the selected month's history" do
    category = create(:category)
    target_month = 2.months.ago.to_date
    create(:transaction, category: category, description: "Mercado", amount: 100, kind: :expense, date: Date.current)
    create(:transaction, category: category, description: "Conserto do carro", amount: 300, kind: :expense, date: target_month)

    get root_path, params: { month: target_month.strftime("%Y-%m") }

    expect(response.body).to include("Conserto do carro")
    expect(response.body).not_to include("Mercado")
  end

  it "redirects to sign in when not authenticated" do
    sign_out user
    get root_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows navigation links" do
    get root_path

    expect(response.body).to include(categories_path)
    expect(response.body).to include(transactions_path)
    expect(response.body).to include(recurring_entries_path)
  end

  it "shows the month's income and expense totals regardless of the history filter" do
    # Two transactions per kind, no single one equal to the total, so the
    # assertions below can only pass if a *summed* total is rendered
    # somewhere — not just each transaction's own line in the list below.
    expense_category = create(:category, kind: :expense)
    income_category = create(:category, kind: :income)
    create(:transaction, category: expense_category, kind: :expense, amount: 40, date: Date.current)
    create(:transaction, category: expense_category, kind: :expense, amount: 60, date: Date.current)
    create(:transaction, category: income_category, kind: :income, amount: 150, date: Date.current)
    create(:transaction, category: income_category, kind: :income, amount: 200, date: Date.current)

    get root_path, params: { month: "all" }

    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(100, unit: "R$ "))
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(350, unit: "R$ "))
  end
end
