require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "shows account balances and this month's transactions" do
    account = create(:account, name: "Nubank", initial_balance: 1000)
    category = create(:category)
    create(:transaction, account: account, category: category, description: "Mercado", amount: 100, kind: :expense, date: Date.current)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nubank")
    expect(response.body).to include("Mercado")
  end

  it "redirects to sign in when not authenticated" do
    sign_out user
    get root_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows navigation links" do
    get root_path

    expect(response.body).to include(accounts_path)
    expect(response.body).to include(categories_path)
    expect(response.body).to include(transactions_path)
    expect(response.body).to include(recurring_entries_path)
  end

  it "shows the month's income and expense totals" do
    account = create(:account)
    expense_category = create(:category, kind: :expense)
    income_category = create(:category, kind: :income)
    create(:transaction, account: account, category: expense_category, kind: :expense, amount: 100, date: Date.current)
    create(:transaction, account: account, category: income_category, kind: :income, amount: 350, date: Date.current)

    get root_path

    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(100, unit: "R$ "))
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(350, unit: "R$ "))
  end
end
