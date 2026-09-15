require "rails_helper"

RSpec.describe WorkoutSession, type: :model do
  it "is valid with a user, workout_program, program_day and started_at" do
    expect(build(:workout_session)).to be_valid
  end

  it "is invalid without started_at" do
    expect(build(:workout_session, started_at: nil)).not_to be_valid
  end

  it "defaults to in_progress" do
    expect(create(:workout_session).status).to eq("in_progress")
  end

  it "can be marked completed" do
    expect(create(:workout_session, :completed).status).to eq("completed")
  end

  it "is destroyed along with its set_logs" do
    session = create(:workout_session)
    create(:set_log, workout_session: session)

    expect { session.destroy }.to change(SetLog, :count).by(-1)
  end

  describe ".completed_dates_for" do
    it "returns the unique dates with a completed session in the given month" do
      user = create(:user)
      program = create(:workout_program, user: user)
      day = create(:program_day, workout_program: program)
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user, finished_at: Time.zone.local(2026, 9, 5, 10, 0))
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user, finished_at: Time.zone.local(2026, 9, 5, 20, 0))
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user, finished_at: Time.zone.local(2026, 9, 20, 10, 0))

      dates = WorkoutSession.completed_dates_for(user: user, month: Date.new(2026, 9, 1))

      expect(dates).to contain_exactly(Date.new(2026, 9, 5), Date.new(2026, 9, 20))
    end

    it "excludes in_progress sessions and sessions from other months or users" do
      user = create(:user)
      program = create(:workout_program, user: user)
      day = create(:program_day, workout_program: program)
      create(:workout_session, workout_program: program, program_day: day, user: user)
      create(:workout_session, :completed, workout_program: program, program_day: day, user: user, finished_at: Time.zone.local(2026, 8, 31, 10, 0))
      other_user = create(:user)
      other_program = create(:workout_program, user: other_user)
      other_day = create(:program_day, workout_program: other_program)
      create(:workout_session, :completed, workout_program: other_program, program_day: other_day, user: other_user, finished_at: Time.zone.local(2026, 9, 5, 10, 0))

      dates = WorkoutSession.completed_dates_for(user: user, month: Date.new(2026, 9, 1))

      expect(dates).to be_empty
    end
  end
end
