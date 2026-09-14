require "rails_helper"

RSpec.describe WorkoutProgram, type: :model do
  it "is valid with a name and a user" do
    expect(build(:workout_program)).to be_valid
  end

  it "is invalid without a name" do
    expect(build(:workout_program, name: nil)).not_to be_valid
  end

  describe "#activate!" do
    it "activates itself and deactivates the user's other programs" do
      user = create(:user)
      current = create(:workout_program, user: user, active: true)
      other = create(:workout_program, user: user, active: false)

      other.activate!

      expect(other.reload.active).to be true
      expect(current.reload.active).to be false
    end

    it "does not affect another user's active program" do
      other_user_program = create(:workout_program, user: create(:user), active: true)
      program = create(:workout_program, active: false)

      program.activate!

      expect(other_user_program.reload.active).to be true
    end
  end

  it "is destroyed along with its workout_sessions" do
    program = create(:workout_program)
    create(:workout_session, workout_program: program)

    expect { program.destroy }.to change(WorkoutSession, :count).by(-1)
  end
end
