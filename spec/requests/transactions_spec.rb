require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }

  before { sign_in user }

  it "creates a transaction" do
    expect {
      post transactions_path, params: { transaction: { description: "Mercado", amount: 100, kind: "expense", date: Date.current, category_id: category.id } }
    }.to change(Transaction, :count).by(1)
    expect(response).to redirect_to(transactions_path)
    expect(Transaction.last.user).to eq(user)
  end

  it "does not create a transaction with a zero amount" do
    expect {
      post transactions_path, params: { transaction: { description: "Mercado", amount: 0, kind: "expense", date: Date.current, category_id: category.id } }
    }.not_to change(Transaction, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "does not create a transaction referencing another user's category" do
    other_category = create(:category)

    expect {
      post transactions_path, params: { transaction: { description: "Mercado", amount: 100, kind: "expense", date: Date.current, category_id: other_category.id } }
    }.not_to change(Transaction, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates a transaction" do
    transaction = create(:transaction, category: category, user: user)
    patch transaction_path(transaction), params: { transaction: { description: "Novo nome" } }
    expect(transaction.reload.description).to eq("Novo nome")
  end

  it "destroys a transaction" do
    transaction = create(:transaction, category: category, user: user)
    expect { delete transaction_path(transaction) }.to change(Transaction, :count).by(-1)
  end

  it "returns 404 when trying to view another user's transaction" do
    other_transaction = create(:transaction)
    get transaction_path(other_transaction)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when trying to update another user's transaction" do
    other_transaction = create(:transaction, description: "Original")
    patch transaction_path(other_transaction), params: { transaction: { description: "Hackeado" } }
    expect(response).to have_http_status(:not_found)
    expect(other_transaction.reload.description).to eq("Original")
  end

  it "returns 404 when trying to destroy another user's transaction" do
    other_transaction = create(:transaction)
    expect { delete transaction_path(other_transaction) }.not_to change(Transaction, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "renders both a desktop table and a mobile card list for the same transactions" do
    create(:transaction, category: category, user: user, description: "Mercado")

    get transactions_path

    expect(response.body).to include('data-testid="transactions-table"')
    expect(response.body).to include('data-testid="transactions-cards"')
    expect(response.body.scan("Mercado").count).to eq(2)
  end

  it "omits the visible type badge and category from the mobile card, keeping only date, description and amount (with a screen-reader-only type label)" do
    transaction = create(:transaction, category: category, user: user, description: "Mercado", kind: :expense, amount: 42)

    get transactions_path

    doc = Nokogiri::HTML(response.body)
    cards = doc.at_css('[data-testid="transactions-cards"]')

    expect(cards.text).to include("Mercado")
    expect(cards.text).to include(ActionController::Base.helpers.number_to_currency(42, unit: "R$ "))
    expect(cards.css("span.rounded-full")).to be_empty
    expect(cards.at_css("span.sr-only").text).to eq("Gasto")
    expect(cards.text).not_to include(category.name)
  end

  it "only lists the current user's categories in the new transaction form" do
    create(:category, name: "Categoria de outro usuário")

    get new_transaction_path

    expect(response.body).not_to include("Categoria de outro usuário")
  end
end
