require "rails_helper"

RSpec.describe "RecurringEntries", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }

  before { sign_in user }

  it "creates a recurring entry" do
    expect {
      post recurring_entries_path, params: { recurring_entry: { description: "Aluguel", amount: 1500, kind: "expense", day_of_month: 5, active: true, start_date: Date.current, category_id: category.id } }
    }.to change(RecurringEntry, :count).by(1)
    expect(response).to redirect_to(recurring_entries_path)
    expect(RecurringEntry.last.user).to eq(user)
  end

  it "generates this month's transaction immediately when the day_of_month has already passed" do
    day_already_passed = [ Date.current.day - 1, 1 ].max

    expect {
      post recurring_entries_path, params: { recurring_entry: { description: "Aluguel", amount: 1500, kind: "expense", day_of_month: day_already_passed, active: true, start_date: Date.current.beginning_of_month, category_id: category.id } }
    }.to change(Transaction, :count).by(1)

    expect(RecurringEntry.last.transactions.count).to eq(1)
    expect(RecurringEntry.last.transactions.first.user).to eq(user)
  end

  it "does not create a recurring entry with an invalid day_of_month" do
    expect {
      post recurring_entries_path, params: { recurring_entry: { description: "Aluguel", amount: 1500, kind: "expense", day_of_month: 40, active: true, start_date: Date.current, category_id: category.id } }
    }.not_to change(RecurringEntry, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "does not create a recurring entry referencing another user's category" do
    other_category = create(:category)

    expect {
      post recurring_entries_path, params: { recurring_entry: { description: "Aluguel", amount: 1500, kind: "expense", day_of_month: 5, active: true, start_date: Date.current, category_id: other_category.id } }
    }.not_to change(RecurringEntry, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates a recurring entry" do
    entry = create(:recurring_entry, category: category, user: user)
    patch recurring_entry_path(entry), params: { recurring_entry: { active: false } }
    expect(entry.reload.active).to be(false)
  end

  it "destroys a recurring entry" do
    entry = create(:recurring_entry, category: category, user: user)
    expect { delete recurring_entry_path(entry) }.to change(RecurringEntry, :count).by(-1)
  end

  it "returns 404 when trying to view another user's recurring entry" do
    other_entry = create(:recurring_entry)
    get recurring_entry_path(other_entry)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when trying to update another user's recurring entry" do
    other_entry = create(:recurring_entry, active: true)
    patch recurring_entry_path(other_entry), params: { recurring_entry: { active: false } }
    expect(response).to have_http_status(:not_found)
    expect(other_entry.reload.active).to be(true)
  end

  it "returns 404 when trying to destroy another user's recurring entry" do
    other_entry = create(:recurring_entry)
    expect { delete recurring_entry_path(other_entry) }.not_to change(RecurringEntry, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "does not generate transactions for another user's due recurring entries" do
    other_user = create(:user)
    other_category = create(:category, user: other_user)
    other_entry = create(:recurring_entry, category: other_category, user: other_user, day_of_month: Date.current.day, start_date: Date.current.beginning_of_month)

    post recurring_entries_path, params: { recurring_entry: { description: "Aluguel", amount: 1500, kind: "expense", day_of_month: Date.current.day, active: true, start_date: Date.current, category_id: category.id } }

    expect(other_entry.transactions).to be_empty
  end

  it "only lists the current user's categories in the new recurring entry form" do
    create(:category, name: "Categoria de outro usuário")

    get new_recurring_entry_path

    expect(response.body).not_to include("Categoria de outro usuário")
  end

  it "renders both a desktop table and a mobile card list for the same recurring entries" do
    create(:recurring_entry, category: category, user: user, description: "Aluguel")

    get recurring_entries_path

    expect(response.body).to include('data-testid="recurring-entries-table"')
    expect(response.body).to include('data-testid="recurring-entries-cards"')
    expect(response.body.scan("Aluguel").count).to eq(2)
  end

  it "omits the visible type, category, status and end date badges from the mobile card, keeping only day, description and amount (with screen-reader-only labels for the rest)" do
    create(:recurring_entry, category: category, user: user, description: "Aluguel", kind: :expense, amount: 1500, day_of_month: 5, active: true)

    get recurring_entries_path

    doc = Nokogiri::HTML(response.body)
    cards = doc.at_css('[data-testid="recurring-entries-cards"]')

    expect(cards.text).to include("Aluguel")
    expect(cards.text).to include("Dia 5")
    expect(cards.text).to include(ActionController::Base.helpers.number_to_currency(1500, unit: "R$ "))
    expect(cards.css("span.rounded-full")).to be_empty

    sr_only_texts = cards.css("span.sr-only").map(&:text)
    expect(sr_only_texts).to include("Gasto")
    expect(sr_only_texts).to include("Categoria: #{category.name}")
    expect(sr_only_texts).to include("Status: Ativa")
    expect(sr_only_texts).to include("Até: Sem fim")
  end
end
