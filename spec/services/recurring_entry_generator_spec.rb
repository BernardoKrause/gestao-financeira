require "rails_helper"

RSpec.describe RecurringEntryGenerator do
  let(:category) { create(:category) }

  it "generates a transaction for an entry due today" do
    entry = create(:recurring_entry, category: category, day_of_month: 10, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 10))

    transaction = entry.transactions.sole
    expect(transaction.amount).to eq(entry.amount)
    expect(transaction.kind).to eq(entry.kind)
    expect(transaction.date).to eq(Date.new(2026, 3, 10))
    expect(transaction.category).to eq(category)
  end

  it "does not generate a transaction before the entry's day_of_month" do
    entry = create(:recurring_entry, category: category, day_of_month: 20, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 10))

    expect(entry.transactions).to be_empty
  end

  it "does not generate a duplicate transaction in the same month" do
    entry = create(:recurring_entry, category: category, day_of_month: 5, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 5))
    described_class.call(today: Date.new(2026, 3, 20))

    expect(entry.transactions.count).to eq(1)
  end

  it "does not generate a transaction for an inactive entry" do
    entry = create(:recurring_entry, category: category, day_of_month: 5, active: false, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 5))

    expect(entry.transactions).to be_empty
  end

  it "does not generate a transaction after end_date" do
    entry = create(:recurring_entry, category: category, day_of_month: 5, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 2, 28))

    described_class.call(today: Date.new(2026, 3, 5))

    expect(entry.transactions).to be_empty
  end

  it "generates the next month's transaction after end of previous month" do
    entry = create(:recurring_entry, category: category, day_of_month: 5, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 5))
    described_class.call(today: Date.new(2026, 4, 5))

    expect(entry.transactions.count).to eq(2)
  end

  it "clamps a day_of_month past the end of a shorter month to the last day of that month" do
    entry = create(:recurring_entry, category: category, day_of_month: 31, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 4, 30))

    transaction = entry.transactions.sole
    expect(transaction.date).to eq(Date.new(2026, 4, 30))
  end

  it "does not generate the clamped transaction before the last day of a shorter month" do
    entry = create(:recurring_entry, category: category, day_of_month: 31, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 4, 29))

    expect(entry.transactions).to be_empty
  end
end
