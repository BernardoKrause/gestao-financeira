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
end
