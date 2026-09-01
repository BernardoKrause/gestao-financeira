require "rails_helper"

RSpec.describe Setting, type: :model do
  describe ".instance" do
    it "creates the single row on first access" do
      expect { Setting.instance }.to change(Setting, :count).by(1)
    end

    it "returns the same row on subsequent calls" do
      first = Setting.instance
      expect(Setting.instance).to eq(first)
    end
  end

  describe "#current_balance" do
    it "adds signed transaction amounts to the initial balance" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:transaction, category: category, kind: :expense, amount: 200, date: Date.new(2026, 3, 10))
      create(:transaction, category: category, kind: :income, amount: 300, date: Date.new(2026, 3, 15))

      expect(setting.current_balance(as_of: Date.new(2026, 3, 20))).to eq(1100)
    end

    it "ignores transactions after the as_of date" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:transaction, category: category, kind: :expense, amount: 200, date: Date.new(2026, 3, 25))

      expect(setting.current_balance(as_of: Date.new(2026, 3, 20))).to eq(1000)
    end
  end

  describe "#projected_month_end_balance" do
    it "adds pending active recurring entries for the rest of the month" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1200)
    end

    it "ignores recurring entries whose day_of_month already passed" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 5, start_date: Date.new(2026, 1, 1))

      expect(setting.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1000)
    end

    it "ignores inactive recurring entries" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 25, active: false, start_date: Date.new(2026, 1, 1))

      expect(setting.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1000)
    end

    it "does not double-count a recurring entry that already fired today via the month-end clamp" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      entry = create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 31, start_date: Date.new(2026, 1, 1))
      create(:transaction, category: category, kind: :expense, amount: 300, date: Date.new(2026, 4, 30), recurring_entry: entry)

      expect(setting.projected_month_end_balance(as_of: Date.new(2026, 4, 30))).to eq(700)
    end
  end

  describe "#pending_recurring_income_total" do
    it "sums only pending income entries" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.pending_recurring_income_total(as_of: Date.new(2026, 3, 10))).to eq(500)
    end
  end

  describe "#pending_recurring_expense_total" do
    it "sums only pending expense entries" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.pending_recurring_expense_total(as_of: Date.new(2026, 3, 10))).to eq(300)
    end
  end

  describe "#cash_flow_series" do
    it "fills historical for days up to and including as_of, and leaves later days nil" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:transaction, category: category, kind: :expense, amount: 100, date: Date.new(2026, 3, 5))

      series = setting.cash_flow_series(month: Date.new(2026, 3, 1), as_of: Date.new(2026, 3, 10))

      expect(series[:labels]).to eq((1..31).to_a)
      expect(series[:historical][3]).to eq(1000)   # day 4, before the expense
      expect(series[:historical][4]).to eq(900)    # day 5, expense applied
      expect(series[:historical][9]).to eq(900)    # day 10 == as_of
      expect(series[:historical][10]).to be_nil    # day 11, after as_of
    end

    it "fills projected from as_of onward using active recurring entries, and leaves earlier days nil" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      series = setting.cash_flow_series(month: Date.new(2026, 3, 1), as_of: Date.new(2026, 3, 10))

      expect(series[:projected][8]).to be_nil       # day 9, before as_of
      expect(series[:projected][9]).to eq(1000)     # day 10 == as_of, no entries fired yet
      expect(series[:projected][24]).to eq(700)      # day 25, expense fires
      expect(series[:projected][27]).to eq(1200)     # day 28, income fires on top
      expect(series[:projected][30]).to eq(1200)     # day 31, unchanged after the last entry
    end

    it "does not double count a recurring entry firing on the last valid day of a shorter month" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 31, start_date: Date.new(2026, 1, 1))

      series = setting.cash_flow_series(month: Date.new(2026, 4, 1), as_of: Date.new(2026, 4, 10))

      expect(series[:labels].size).to eq(30)
      expect(series[:projected][29]).to eq(700) # April 30 — clamped fire day for day_of_month 31
    end

    it "ends the projected series at the same value as the KPI card's projected month-end balance" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 31, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      as_of = Date.new(2026, 4, 10)
      series = setting.cash_flow_series(month: as_of, as_of: as_of)

      expect(series[:projected].last).to eq(setting.projected_month_end_balance(as_of: as_of))
    end
  end

  describe "#financial_health_status" do
    it "is :critical when the projected balance is negative" do
      setting = create(:setting, initial_balance: 100)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 500, day_of_month: 25, start_date: Date.new(2026, 1, 1))

      expect(setting.financial_health_status(as_of: Date.new(2026, 3, 10))).to eq(:critical)
    end

    it "is :warning when the projected balance is non-negative but lower than the current balance" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 100, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.financial_health_status(as_of: Date.new(2026, 3, 10))).to eq(:warning)
    end

    it "is :healthy when the projected balance is at or above the current balance" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 100, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 300, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.financial_health_status(as_of: Date.new(2026, 3, 10))).to eq(:healthy)
    end

    it "is :healthy at the boundary where projected equals current (flat month)" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 200, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 200, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.financial_health_status(as_of: Date.new(2026, 3, 10))).to eq(:healthy)
    end

    it "is :warning for a structurally deficit month even after every recurring entry has already fired" do
      setting = create(:setting, initial_balance: 10_000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 5000, day_of_month: 5, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 1000, day_of_month: 20, start_date: Date.new(2026, 1, 1))

      # Both entries' fire days have already passed this month, so nothing
      # is "pending" — under the old rule this collapsed to :healthy.
      expect(setting.financial_health_status(as_of: Date.new(2026, 3, 25))).to eq(:warning)
    end

    it "is :healthy for a structurally balanced month even after every recurring entry has already fired" do
      setting = create(:setting, initial_balance: 10_000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 500, day_of_month: 5, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 1000, day_of_month: 20, start_date: Date.new(2026, 1, 1))

      expect(setting.financial_health_status(as_of: Date.new(2026, 3, 25))).to eq(:healthy)
    end
  end

  describe "#projected_balance_for" do
    it "returns only the current balance for :confirmed" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))
      create(:transaction, category: category, kind: :income, amount: 200, date: Date.new(2026, 3, 15))

      expect(setting.projected_balance_for(confidence: :confirmed, as_of: Date.new(2026, 3, 10))).to eq(1000)
    end

    it "matches projected_month_end_balance for :recurring" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))
      create(:transaction, category: category, kind: :income, amount: 200, date: Date.new(2026, 3, 15))

      expect(setting.projected_balance_for(confidence: :recurring, as_of: Date.new(2026, 3, 10)))
        .to eq(setting.projected_month_end_balance(as_of: Date.new(2026, 3, 10)))
    end

    it "also counts future one-off transactions this month for :all" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))
      create(:transaction, category: category, kind: :income, amount: 200, date: Date.new(2026, 3, 15))
      create(:transaction, category: category, kind: :expense, amount: 50, date: Date.new(2026, 3, 20))
      # Outside this month — must not be counted even for :all.
      create(:transaction, category: category, kind: :income, amount: 9999, date: Date.new(2026, 4, 5))

      expect(setting.projected_balance_for(confidence: :all, as_of: Date.new(2026, 3, 10))).to eq(1650) # 1000 + 500 + 200 - 50
    end

    it "raises for an unknown confidence level" do
      setting = create(:setting)
      expect { setting.projected_balance_for(confidence: :optimistic) }.to raise_error(ArgumentError)
    end
  end

  describe "#financial_health_status_for" do
    it "flags :warning for every confidence level when the month structurally runs a recurring deficit, even though :confirmed's own balance is currently positive" do
      setting = create(:setting, initial_balance: 100)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 500, day_of_month: 25, start_date: Date.new(2026, 1, 1))

      expect(setting.financial_health_status_for(confidence: :confirmed, as_of: Date.new(2026, 3, 10))).to eq(:warning)
      expect(setting.financial_health_status_for(confidence: :recurring, as_of: Date.new(2026, 3, 10))).to eq(:critical)
      expect(setting.financial_health_status_for(confidence: :all, as_of: Date.new(2026, 3, 10))).to eq(:critical)
    end

    it "returns :healthy for :confirmed when the month has no recurring deficit at all" do
      setting = create(:setting, initial_balance: 100)

      expect(setting.financial_health_status_for(confidence: :confirmed, as_of: Date.new(2026, 3, 10))).to eq(:healthy)
    end
  end
end
