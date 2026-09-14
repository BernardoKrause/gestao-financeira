require "rails_helper"

RSpec.describe ProgramExercise, type: :model do
  it "is valid for a strength exercise with target sets and reps" do
    expect(build(:program_exercise)).to be_valid
  end

  it "is valid for a cardio exercise with a target duration" do
    expect(build(:program_exercise, :cardio)).to be_valid
  end

  it "is invalid without target_sets when the exercise is strength" do
    expect(build(:program_exercise, target_sets: nil)).not_to be_valid
  end

  it "is invalid without target_reps when the exercise is strength" do
    expect(build(:program_exercise, target_reps: nil)).not_to be_valid
  end

  it "is invalid without target_duration_minutes when the exercise is cardio" do
    expect(build(:program_exercise, :cardio, target_duration_minutes: nil)).not_to be_valid
  end

  it "is destroyed along with its program day" do
    program_exercise = create(:program_exercise)
    day = program_exercise.program_day

    expect { day.destroy }.to change(ProgramExercise, :count).by(-1)
  end
end
