require "rails_helper"

RSpec.describe "Accounts", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "creates an account" do
    expect {
      post accounts_path, params: { account: { name: "Nubank", account_type: "checking", initial_balance: 100 } }
    }.to change(Account, :count).by(1)
    expect(response).to redirect_to(accounts_path)
  end

  it "does not create an account without a name" do
    expect {
      post accounts_path, params: { account: { name: "", account_type: "checking", initial_balance: 100 } }
    }.not_to change(Account, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates an account" do
    account = create(:account)
    patch account_path(account), params: { account: { name: "Novo nome" } }
    expect(account.reload.name).to eq("Novo nome")
  end

  it "destroys an account" do
    account = create(:account)
    expect { delete account_path(account) }.to change(Account, :count).by(-1)
  end
end
