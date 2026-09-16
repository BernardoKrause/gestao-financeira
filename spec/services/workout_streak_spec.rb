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

  describe "#current_streak_weeks" do
    it "counts consecutive weeks (including the current one) that met the goal" do
      user = create(:user)
      program = create(:workout_program, user: user, active: true)
      create(:program_day, workout_program: program)
      day = program.program_days.first

      travel_to Time.zone.local(2026, 9, 16, 12, 0) # Wednesday of week starting 2026-09-13
      # This week: 1/1 met already (goal is 1 day)
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user,
             finished_at: Time.zone.local(2026, 9, 14, 10, 0))
      # Last week: met
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user,
             finished_at: Time.zone.local(2026, 9, 8, 10, 0))
      # Two weeks ago: not met (no session)

      streak = described_class.new(user)

      expect(streak.current_streak_weeks).to eq(2)
      travel_back
    end

    it "does not break the streak while the current week is still pending" do
      user = create(:user)
      program = create(:workout_program, user: user, active: true)
      create(:program_day, workout_program: program, position: 0)
      create(:program_day, workout_program: program, position: 1) # goal = 2/week
      day = program.program_days.first

      travel_to Time.zone.local(2026, 9, 16, 12, 0) # Wednesday, current week has 0 sessions so far
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user,
             finished_at: Time.zone.local(2026, 9, 8, 10, 0))
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user,
             finished_at: Time.zone.local(2026, 9, 9, 10, 0)) # last week: 2/2, met

      streak = described_class.new(user)

      expect(streak.current_streak_weeks).to eq(1)
      travel_back
    end

    it "is 0 right after a missed week" do
      user = create(:user)
      program = create(:workout_program, user: user, active: true)
      create(:program_day, workout_program: program)
      day = program.program_days.first

      travel_to Time.zone.local(2026, 9, 16, 12, 0)
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user,
             finished_at: Time.zone.local(2026, 8, 30, 10, 0)) # 2+ weeks ago, no session since

      streak = described_class.new(user)

      expect(streak.current_streak_weeks).to eq(0)
      travel_back
    end
  end

  describe "#longest_streak_weeks and #unlocked_badges" do
    it "keeps the longest streak ever reached even after it breaks" do
      user = create(:user)
      program = create(:workout_program, user: user, active: true)
      create(:program_day, workout_program: program)
      day = program.program_days.first

      travel_to Time.zone.local(2026, 9, 16, 12, 0)
      # 4 consecutive met weeks, then a gap, then the current (unmet) week
      [ 5, 4, 3, 2 ].each do |weeks_ago|
        create(:workout_session, :completed, workout_program: program, program_day: day, user: user,
               finished_at: weeks_ago.weeks.ago)
      end

      streak = described_class.new(user)

      expect(streak.longest_streak_weeks).to eq(4)
      expect(streak.current_streak_weeks).to eq(0)
      expect(streak.unlocked_badges).to eq([ 4 ])
      travel_back
    end

    it "returns no badges below the 4-week milestone" do
      user = create(:user)
      program = create(:workout_program, user: user, active: true)
      create(:program_day, workout_program: program)
      day = program.program_days.first
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user,
             finished_at: Time.current)

      streak = described_class.new(user)

      expect(streak.unlocked_badges).to eq([])
    end
  end
end
