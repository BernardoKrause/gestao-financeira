require "rails_helper"

RSpec.describe Transaction, type: :model do
  it "is valid with description, amount, kind, date, account and category" do
    expect(build(:transaction)).to be_valid
  end

  it "is invalid without a description" do
    expect(build(:transaction, description: nil)).not_to be_valid
  end

  it "is invalid with a zero amount" do
    expect(build(:transaction, amount: 0)).not_to be_valid
  end

  describe "#signed_amount" do
    it "is negative for an expense" do
      transaction = build(:transaction, kind: :expense, amount: 100)
      expect(transaction.signed_amount).to eq(-100)
    end

    it "is positive for an income" do
      transaction = build(:transaction, kind: :income, amount: 100)
      expect(transaction.signed_amount).to eq(100)
    end
  end
end
