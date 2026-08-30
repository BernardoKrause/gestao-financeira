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

  it "shows the selected period's income and expense totals" do
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

  it "changes the totals when a different month is selected" do
    category = create(:category, kind: :expense)
    older_month = 2.months.ago.to_date
    create(:transaction, category: category, kind: :expense, amount: 999, date: Date.current)
    create(:transaction, category: category, kind: :expense, amount: 77, date: older_month)

    get root_path, params: { month: older_month.strftime("%Y-%m") }

    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(77, unit: "R$ "))
    expect(response.body).not_to include(ActionController::Base.helpers.number_to_currency(999, unit: "R$ "))
  end

  it "shows the financial health KPI card with the income/expense breakdown and a status badge" do
    Setting.instance.update!(initial_balance: 1000)
    category = create(:category)
    create(:recurring_entry, category: category, kind: :expense, amount: 100, day_of_month: 25, start_date: Date.new(2026, 1, 1))
    create(:recurring_entry, category: category, kind: :income, amount: 300, day_of_month: 28, start_date: Date.new(2026, 1, 1))

    travel_to Date.new(2026, 3, 10) do
      get root_path
    end

    expect(response.body).to include("Previsão fim do mês")
    expect(response.body).to include("Saudável")
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(1000, unit: "R$ ")) # saldo atual
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(300, unit: "R$ "))  # receita prevista
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(100, unit: "R$ "))  # despesa prevista
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(1200, unit: "R$ ")) # saldo projetado
  end
end
