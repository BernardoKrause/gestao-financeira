require "rails_helper"

RSpec.describe RecurringEntry, type: :model do
  it "is valid with the factory defaults" do
    expect(build(:recurring_entry)).to be_valid
  end

  it "is invalid when the category belongs to a different user" do
    user = create(:user)
    other_user = create(:user)
    category = create(:category, user: other_user)

    entry = build(:recurring_entry, user: user, category: category)

    expect(entry).not_to be_valid
    expect(entry.errors[:category]).to be_present
  end

  it "is invalid without a day_of_month" do
    expect(build(:recurring_entry, day_of_month: nil)).not_to be_valid
  end

  it "is invalid with a day_of_month greater than 31" do
    expect(build(:recurring_entry, day_of_month: 32)).not_to be_valid
  end

  it "is invalid with installments less than 1" do
    expect(build(:recurring_entry, installments: 0)).not_to be_valid
  end

  describe "#end_date" do
    it "is nil when installments is blank" do
      entry = build(:recurring_entry, installments: nil)
      expect(entry.end_date).to be_nil
    end

    it "counts start_date's own month as the first installment" do
      entry = build(:recurring_entry, day_of_month: 5, start_date: Date.new(2026, 1, 1), installments: 3)
      expect(entry.end_date).to eq(Date.new(2026, 3, 5))
    end

    it "clamps to the last day of a shorter month, like the generator does" do
      entry = build(:recurring_entry, day_of_month: 31, start_date: Date.new(2026, 1, 1), installments: 4)
      expect(entry.end_date).to eq(Date.new(2026, 4, 30))
    end
  end

  describe ".active" do
    it "returns only active entries" do
      user = create(:user)
      category = create(:category, user: user)
      active_entry = create(:recurring_entry, active: true, user: user, category: category)
      create(:recurring_entry, active: false, user: user, category: category)
      expect(RecurringEntry.active).to contain_exactly(active_entry)
    end
  end
end
