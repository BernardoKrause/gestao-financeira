require "rails_helper"

RSpec.describe RecurringEntry, type: :model do
  it "is valid with the factory defaults" do
    expect(build(:recurring_entry)).to be_valid
  end

  it "is invalid without a day_of_month" do
    expect(build(:recurring_entry, day_of_month: nil)).not_to be_valid
  end

  it "is invalid with a day_of_month greater than 31" do
    expect(build(:recurring_entry, day_of_month: 32)).not_to be_valid
  end

  it "is invalid when end_date is before start_date" do
    entry = build(:recurring_entry, start_date: Date.new(2026, 3, 1), end_date: Date.new(2026, 2, 1))
    expect(entry).not_to be_valid
    expect(entry.errors[:end_date]).to be_present
  end

  describe ".active" do
    it "returns only active entries" do
      active_entry = create(:recurring_entry, active: true)
      create(:recurring_entry, active: false)
      expect(RecurringEntry.active).to contain_exactly(active_entry)
    end
  end
end
