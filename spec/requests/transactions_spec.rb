require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:category) }

  before { sign_in user }

  it "creates a transaction" do
    expect {
      post transactions_path, params: { transaction: { description: "Mercado", amount: 100, kind: "expense", date: Date.current, category_id: category.id } }
    }.to change(Transaction, :count).by(1)
    expect(response).to redirect_to(transactions_path)
  end

  it "does not create a transaction with a zero amount" do
    expect {
      post transactions_path, params: { transaction: { description: "Mercado", amount: 0, kind: "expense", date: Date.current, category_id: category.id } }
    }.not_to change(Transaction, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates a transaction" do
    transaction = create(:transaction, category: category)
    patch transaction_path(transaction), params: { transaction: { description: "Novo nome" } }
    expect(transaction.reload.description).to eq("Novo nome")
  end

  it "destroys a transaction" do
    transaction = create(:transaction, category: category)
    expect { delete transaction_path(transaction) }.to change(Transaction, :count).by(-1)
  end
end
