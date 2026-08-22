require "rails_helper"

RSpec.describe Category, type: :model do
  it "is valid with a name and kind" do
    expect(build(:category)).to be_valid
  end

  it "is invalid without a name" do
    expect(build(:category, name: nil)).not_to be_valid
  end

  it "exposes expense and income kinds" do
    expect(Category.kinds.keys).to contain_exactly("expense", "income")
  end
end
