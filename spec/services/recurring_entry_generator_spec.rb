require "rails_helper"

RSpec.describe RecurringEntryGenerator do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }

  it "generates a transaction for an entry due today" do
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 10, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 10))

    transaction = entry.transactions.sole
    expect(transaction.amount).to eq(entry.amount)
    expect(transaction.kind).to eq(entry.kind)
    expect(transaction.date).to eq(Date.new(2026, 3, 10))
    expect(transaction.category).to eq(category)
    expect(transaction.user).to eq(user)
  end

  it "does not generate a transaction before the entry's day_of_month" do
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 20, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 10))

    expect(entry.transactions).to be_empty
  end

  it "does not generate a duplicate transaction in the same month" do
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 5, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 5))
    described_class.call(today: Date.new(2026, 3, 20))

    expect(entry.transactions.count).to eq(1)
  end

  it "does not generate a transaction for an inactive entry" do
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 5, active: false, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 5))

    expect(entry.transactions).to be_empty
  end

  it "does not generate a transaction after the last installment" do
    # start_date Jan 1 (installment 1's month), day_of_month 5, 2 installments
    # -> end_date Feb 5, so nothing should fire in March.
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 5, start_date: Date.new(2026, 1, 1), installments: 2)

    described_class.call(today: Date.new(2026, 3, 5))

    expect(entry.transactions).to be_empty
  end

  it "stops generating once the installment count is reached" do
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 5, start_date: Date.new(2026, 1, 1), installments: 2)

    described_class.call(today: Date.new(2026, 1, 5))
    described_class.call(today: Date.new(2026, 2, 5))
    described_class.call(today: Date.new(2026, 3, 5))

    expect(entry.transactions.count).to eq(2)
  end

  it "generates the next month's transaction after end of previous month" do
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 5, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 5))
    described_class.call(today: Date.new(2026, 4, 5))

    expect(entry.transactions.count).to eq(2)
  end

  it "clamps a day_of_month past the end of a shorter month to the last day of that month" do
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 31, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 4, 30))

    transaction = entry.transactions.sole
    expect(transaction.date).to eq(Date.new(2026, 4, 30))
  end

  it "does not generate the clamped transaction before the last day of a shorter month" do
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 31, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 4, 29))

    expect(entry.transactions).to be_empty
  end

  it "only processes the given user's entries when scoped to a user" do
    other_user = create(:user)
    other_category = create(:category, user: other_user)
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 10, start_date: Date.new(2026, 1, 1))
    other_entry = create(:recurring_entry, category: other_category, user: other_user, day_of_month: 10, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 10), user: user)

    expect(entry.transactions.count).to eq(1)
    expect(other_entry.transactions).to be_empty
  end

  it "generates transactions for multiple users' entries independently" do
    other_user = create(:user)
    other_category = create(:category, user: other_user)
    entry = create(:recurring_entry, category: category, user: user, day_of_month: 10, start_date: Date.new(2026, 1, 1))
    other_entry = create(:recurring_entry, category: other_category, user: other_user, day_of_month: 10, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 10))

    expect(entry.transactions.sole.user).to eq(user)
    expect(other_entry.transactions.sole.user).to eq(other_user)
  end
end
