require "rails_helper"

RSpec.describe Exercise, type: :model do
  it "is valid as a global exercise (no user)" do
    expect(build(:exercise, user: nil)).to be_valid
  end

  it "is valid as a custom exercise owned by a user" do
    expect(build(:exercise, :custom)).to be_valid
  end

  it "is invalid without a name" do
    expect(build(:exercise, name: nil)).not_to be_valid
  end

  it "exposes the 8 muscle groups" do
    expect(Exercise.muscle_groups.keys).to contain_exactly(
      "chest", "triceps", "back", "biceps", "legs", "glutes", "shoulders", "abs"
    )
  end

  it "exposes strength, cardio and stretching kinds" do
    expect(Exercise.kinds.keys).to contain_exactly("strength", "cardio", "stretching")
  end

  it "MUSCLE_GROUP_LABELS and KIND_LABELS cover every enum key with no gaps or stray entries" do
    expect(Exercise::MUSCLE_GROUP_LABELS.keys).to match_array(Exercise.muscle_groups.keys)
    expect(Exercise::KIND_LABELS.keys).to match_array(Exercise.kinds.keys)
  end

  describe ".visible_to" do
    it "includes global exercises and the given user's custom exercises, excluding other users'" do
      global = create(:exercise, user: nil)
      user = create(:user)
      mine = create(:exercise, :custom, user: user)
      other = create(:exercise, :custom)

      expect(Exercise.visible_to(user)).to contain_exactly(global, mine)
      expect(Exercise.visible_to(user)).not_to include(other)
    end
  end

  it "#global? is true only when there is no owning user" do
    expect(build(:exercise, user: nil).global?).to be true
    expect(build(:exercise, :custom).global?).to be false
  end
end
