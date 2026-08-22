require "rails_helper"

RSpec.describe "RecurringEntries", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:category) }

  before { sign_in user }

  it "creates a recurring entry" do
    expect {
      post recurring_entries_path, params: { recurring_entry: { description: "Aluguel", amount: 1500, kind: "expense", day_of_month: 5, active: true, start_date: Date.current, category_id: category.id } }
    }.to change(RecurringEntry, :count).by(1)
    expect(response).to redirect_to(recurring_entries_path)
  end

  it "generates this month's transaction immediately when the day_of_month has already passed" do
    day_already_passed = [ Date.current.day - 1, 1 ].max

    expect {
      post recurring_entries_path, params: { recurring_entry: { description: "Aluguel", amount: 1500, kind: "expense", day_of_month: day_already_passed, active: true, start_date: Date.current.beginning_of_month, category_id: category.id } }
    }.to change(Transaction, :count).by(1)

    expect(RecurringEntry.last.transactions.count).to eq(1)
  end

  it "does not create a recurring entry with an invalid day_of_month" do
    expect {
      post recurring_entries_path, params: { recurring_entry: { description: "Aluguel", amount: 1500, kind: "expense", day_of_month: 40, active: true, start_date: Date.current, category_id: category.id } }
    }.not_to change(RecurringEntry, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates a recurring entry" do
    entry = create(:recurring_entry, category: category)
    patch recurring_entry_path(entry), params: { recurring_entry: { active: false } }
    expect(entry.reload.active).to be(false)
  end

  it "destroys a recurring entry" do
    entry = create(:recurring_entry, category: category)
    expect { delete recurring_entry_path(entry) }.to change(RecurringEntry, :count).by(-1)
  end
end
