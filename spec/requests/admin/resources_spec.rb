require "rails_helper"

RSpec.describe "Admin resources smoke test", type: :request do
  let(:admin) { create(:user, email: "admin@example.com") }

  before do
    allow(Rails.application.credentials).to receive(:admin_email).and_return("admin@example.com")
    sign_in admin
  end

  it "lists transactions" do
    category = create(:category, user: admin)
    transaction = create(:transaction, user: admin, category: category)
    get "/admin/resources/transactions"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(transaction.description)
  end

  it "lists recurring entries" do
    category = create(:category, user: admin)
    entry = create(:recurring_entry, user: admin, category: category)
    get "/admin/resources/recurring_entries"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(entry.description)
  end

  it "lists settings" do
    setting = create(:setting, user: admin)
    get "/admin/resources/settings"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(setting.initial_balance.to_s)
  end
end
