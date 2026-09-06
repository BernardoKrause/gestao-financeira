require "rails_helper"

RSpec.describe "Admin overview", type: :request do
  let(:admin) { create(:user, email: "admin@example.com") }

  before do
    allow(Rails.application.credentials).to receive(:admin_email).and_return("admin@example.com")
    sign_in admin
  end

  it "shows the current counters for every administrable resource" do
    category = create(:category, user: admin)
    create(:transaction, user: admin, category: category)
    create(:recurring_entry, user: admin, category: category)

    get "/admin/overview"
    expect(response).to have_http_status(:ok)

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css("[data-testid='users-count']").text.strip).to eq(User.count.to_s)
    expect(doc.at_css("[data-testid='categories-count']").text.strip).to eq(Category.count.to_s)
    expect(doc.at_css("[data-testid='transactions-count']").text.strip).to eq(Transaction.count.to_s)
    expect(doc.at_css("[data-testid='recurring-entries-count']").text.strip).to eq(RecurringEntry.count.to_s)
  end
end
