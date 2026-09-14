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
end
