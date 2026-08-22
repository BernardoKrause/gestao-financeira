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
end
