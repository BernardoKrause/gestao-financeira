require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with an uppercase letter and a special character" do
    user = build(:user, password: "Strong#Pass1", password_confirmation: "Strong#Pass1")
    expect(user).to be_valid
  end

  it "is invalid without an uppercase letter" do
    user = build(:user, password: "weak#pass1", password_confirmation: "weak#pass1")
    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  it "is invalid without a special character" do
    user = build(:user, password: "WeakPass1", password_confirmation: "WeakPass1")
    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  it "destroys a user's transactions and recurring entries before their categories, so a fully-loaded account can be deleted" do
    user = create(:user)
    category = create(:category, user: user)
    create(:transaction, category: category, user: user)
    create(:recurring_entry, category: category, user: user)

    expect { user.destroy }.not_to raise_error
    expect(Category.exists?(category.id)).to be(false)
  end

  it "onboards a new user automatically (setting + default categories) unless skip_onboarding is set" do
    user = User.create!(email: "auto-onboard@example.com", password: "Strong#Pass1", password_confirmation: "Strong#Pass1")

    expect(user.setting).to be_present
    expect(user.setting.initial_balance).to eq(0)
    expect(user.categories.count).to eq(13)
  end

  it "does not onboard a new user when skip_onboarding is true" do
    user = User.create!(email: "skip-onboard@example.com", password: "Strong#Pass1", password_confirmation: "Strong#Pass1", skip_onboarding: true)

    expect(user.setting).to be_nil
    expect(user.categories.count).to eq(0)
  end
end
