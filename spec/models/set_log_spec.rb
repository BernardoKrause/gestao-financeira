require "rails_helper"

RSpec.describe SetLog, type: :model do
  it "is valid with position, reps and weight_kg" do
    expect(build(:set_log)).to be_valid
  end

  it "is valid for cardio with duration_minutes and no reps/weight" do
    expect(build(:set_log, :cardio)).to be_valid
  end

  it "is valid with reps and weight_kg left blank (not filled in yet)" do
    expect(build(:set_log, reps: nil, weight_kg: nil)).to be_valid
  end

  it "is invalid with a zero or negative reps" do
    expect(build(:set_log, reps: 0)).not_to be_valid
    expect(build(:set_log, reps: -1)).not_to be_valid
  end

  it "is invalid with a zero or negative weight_kg" do
    expect(build(:set_log, weight_kg: 0)).not_to be_valid
  end

  it "is invalid with a zero or negative duration_minutes" do
    expect(build(:set_log, :cardio, duration_minutes: 0)).not_to be_valid
  end

  it "is invalid without a position" do
    expect(build(:set_log, position: nil)).not_to be_valid
  end

  it "is destroyed along with its program_exercise" do
    set_log = create(:set_log)
    program_exercise = set_log.program_exercise

    expect { program_exercise.destroy }.to change(SetLog, :count).by(-1)
  end

  describe ".strength_progress_summary" do
    it "maps each strength exercise to its most recent completed, weighted date" do
      user = create(:user)
      program = create(:workout_program, user: user)
      day = create(:program_day, workout_program: program)
      exercise = create(:exercise, kind: :strength)
      program_exercise = create(:program_exercise, program_day: day, exercise: exercise)
      older_session = create(:workout_session, :completed, workout_program: program, program_day: day, user: user, finished_at: 10.days.ago)
      newer_session = create(:workout_session, :completed, workout_program: program, program_day: day, user: user, finished_at: 2.days.ago)
      create(:set_log, :completed, workout_session: older_session, program_exercise: program_exercise, weight_kg: 50)
      create(:set_log, :completed, workout_session: newer_session, program_exercise: program_exercise, weight_kg: 55)

      summary = SetLog.strength_progress_summary(user)

      expect(summary[exercise.id].to_date).to eq(2.days.ago.to_date)
    end

    it "excludes cardio and stretching exercises" do
      user = create(:user)
      program = create(:workout_program, user: user)
      day = create(:program_day, workout_program: program)
      cardio_exercise = create(:exercise, :cardio)
      cardio_program_exercise = create(:program_exercise, :cardio, program_day: day, exercise: cardio_exercise)
      session = create(:workout_session, :completed, workout_program: program, program_day: day, user: user)
      create(:set_log, :cardio, :completed, workout_session: session, program_exercise: cardio_program_exercise, duration_minutes: 20)

      expect(SetLog.strength_progress_summary(user)).to eq({})
    end

    it "excludes incomplete set_logs and set_logs without weight_kg" do
      user = create(:user)
      program = create(:workout_program, user: user)
      day = create(:program_day, workout_program: program)
      exercise = create(:exercise, kind: :strength)
      program_exercise = create(:program_exercise, program_day: day, exercise: exercise)
      session = create(:workout_session, :completed, workout_program: program, program_day: day, user: user)
      create(:set_log, workout_session: session, program_exercise: program_exercise, weight_kg: 40, completed: false)
      create(:set_log, :completed, workout_session: session, program_exercise: program_exercise, weight_kg: nil)

      expect(SetLog.strength_progress_summary(user)).to eq({})
    end

    it "excludes another user's sessions" do
      user = create(:user)
      other_user = create(:user)
      other_program = create(:workout_program, user: other_user)
      other_day = create(:program_day, workout_program: other_program)
      exercise = create(:exercise, kind: :strength)
      program_exercise = create(:program_exercise, program_day: other_day, exercise: exercise)
      other_session = create(:workout_session, :completed, workout_program: other_program, program_day: other_day, user: other_user)
      create(:set_log, :completed, workout_session: other_session, program_exercise: program_exercise, weight_kg: 40)

      expect(SetLog.strength_progress_summary(user)).to eq({})
    end
  end

  describe ".max_weight_by_day" do
    it "returns the max weight per day for the given exercise" do
      user = create(:user)
      program = create(:workout_program, user: user)
      day = create(:program_day, workout_program: program)
      exercise = create(:exercise, kind: :strength)
      program_exercise = create(:program_exercise, program_day: day, exercise: exercise)
      session = create(:workout_session, :completed, workout_program: program, program_day: day, user: user, finished_at: Time.zone.local(2026, 9, 10, 18, 0))
      create(:set_log, :completed, workout_session: session, program_exercise: program_exercise, position: 0, weight_kg: 70)
      create(:set_log, :completed, workout_session: session, program_exercise: program_exercise, position: 1, weight_kg: 75)

      result = SetLog.max_weight_by_day(user: user, exercise_id: exercise.id)

      expect(result[Date.new(2026, 9, 10)]).to eq(75)
    end

    it "excludes days before the since cutoff" do
      user = create(:user)
      program = create(:workout_program, user: user)
      day = create(:program_day, workout_program: program)
      exercise = create(:exercise, kind: :strength)
      program_exercise = create(:program_exercise, program_day: day, exercise: exercise)
      old_session = create(:workout_session, :completed, workout_program: program, program_day: day, user: user, finished_at: 2.months.ago)
      create(:set_log, :completed, workout_session: old_session, program_exercise: program_exercise, weight_kg: 90)

      result = SetLog.max_weight_by_day(user: user, exercise_id: exercise.id, since: 1.month.ago.to_date)

      expect(result).to eq({})
    end

    it "excludes a different exercise's set_logs" do
      user = create(:user)
      program = create(:workout_program, user: user)
      day = create(:program_day, workout_program: program)
      exercise = create(:exercise, kind: :strength)
      other_exercise = create(:exercise, kind: :strength)
      program_exercise = create(:program_exercise, program_day: day, exercise: exercise)
      other_program_exercise = create(:program_exercise, program_day: day, exercise: other_exercise)
      session = create(:workout_session, :completed, workout_program: program, program_day: day, user: user)
      create(:set_log, :completed, workout_session: session, program_exercise: other_program_exercise, weight_kg: 999)

      result = SetLog.max_weight_by_day(user: user, exercise_id: exercise.id)

      expect(result).to eq({})
    end
  end
end
