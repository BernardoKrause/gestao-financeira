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
end
