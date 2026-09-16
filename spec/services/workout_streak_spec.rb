require "rails_helper"

RSpec.describe WorkoutStreak do
  describe "#trackable? and #weekly_goal" do
    it "is not trackable when the user has no active program" do
      user = create(:user)
      create(:workout_program, user: user, active: false)

      streak = described_class.new(user)

      expect(streak.trackable?).to be false
      expect(streak.weekly_goal).to be_nil
    end

    it "is not trackable when the active program has no days" do
      user = create(:user)
      create(:workout_program, user: user, active: true)

      streak = described_class.new(user)

      expect(streak.trackable?).to be false
    end

    it "is trackable with weekly_goal equal to the active program's day count" do
      user = create(:user)
      program = create(:workout_program, user: user, active: true)
      create(:program_day, workout_program: program, position: 0)
      create(:program_day, workout_program: program, position: 1)
      create(:program_day, workout_program: program, position: 2)

      streak = described_class.new(user)

      expect(streak.trackable?).to be true
      expect(streak.weekly_goal).to eq(3)
    end
  end

  describe "#current_week_count" do
    it "counts completed sessions finished within the current Sunday-Saturday week" do
      user = create(:user)
      program = create(:workout_program, user: user, active: true)
      create(:program_day, workout_program: program)
      day = program.program_days.first

      travel_to Time.zone.local(2026, 9, 16, 12, 0)  # a Wednesday
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user,
             finished_at: Time.zone.local(2026, 9, 13, 10, 0))  # Sunday of this week
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user,
             finished_at: Time.zone.local(2026, 9, 6, 10, 0))  # Sunday of last week

      streak = described_class.new(user)

      expect(streak.current_week_count).to eq(1)
      travel_back
    end
  end
end
