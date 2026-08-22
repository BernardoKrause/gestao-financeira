require "rails_helper"

RSpec.describe Account, type: :model do
  it "is valid with a name, account_type and initial_balance" do
    expect(build(:account)).to be_valid
  end

  it "is invalid without a name" do
    expect(build(:account, name: nil)).not_to be_valid
  end

  it "exposes the expected account types" do
    expect(Account.account_types.keys).to contain_exactly("checking", "savings", "credit_card", "cash")
  end

  describe "#current_balance" do
    it "adds signed transaction amounts to the initial balance" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:transaction, account: account, category: category, kind: :expense, amount: 200, date: Date.new(2026, 3, 10))
      create(:transaction, account: account, category: category, kind: :income, amount: 300, date: Date.new(2026, 3, 15))

      expect(account.current_balance(as_of: Date.new(2026, 3, 20))).to eq(1100)
    end

    it "ignores transactions after the as_of date" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:transaction, account: account, category: category, kind: :expense, amount: 200, date: Date.new(2026, 3, 25))

      expect(account.current_balance(as_of: Date.new(2026, 3, 20))).to eq(1000)
    end
  end

  describe "#projected_month_end_balance" do
    it "adds pending active recurring entries for the rest of the month" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, account: account, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, account: account, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(account.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1200)
    end

    it "ignores recurring entries whose day_of_month already passed" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, account: account, category: category, kind: :expense, amount: 300, day_of_month: 5, start_date: Date.new(2026, 1, 1))

      expect(account.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1000)
    end

    it "ignores inactive recurring entries" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, account: account, category: category, kind: :expense, amount: 300, day_of_month: 25, active: false, start_date: Date.new(2026, 1, 1))

      expect(account.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1000)
    end

    it "does not double-count a recurring entry that already fired today via the month-end clamp" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      entry = create(:recurring_entry, account: account, category: category, kind: :expense, amount: 300, day_of_month: 31, start_date: Date.new(2026, 1, 1))
      # April has 30 days: RecurringEntryGenerator would have generated this on April 30 via the clamp (see Task 7).
      create(:transaction, account: account, category: category, kind: :expense, amount: 300, date: Date.new(2026, 4, 30), recurring_entry: entry)

      expect(account.projected_month_end_balance(as_of: Date.new(2026, 4, 30))).to eq(700)
    end

    it "ignores a recurring entry whose end_date is before its fire date this month" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, account: account, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 3, 20))

      expect(account.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1000)
    end

    it "ignores a recurring entry whose start_date is after its fire date this month" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, account: account, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 3, 28))

      expect(account.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1000)
    end
  end
end
