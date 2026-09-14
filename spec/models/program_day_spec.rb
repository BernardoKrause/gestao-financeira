require "rails_helper"

RSpec.describe ProgramDay, type: :model do
  it "is valid with a label, title and position" do
    expect(build(:program_day)).to be_valid
  end

  it "is invalid without a label" do
    expect(build(:program_day, label: nil)).not_to be_valid
  end

  it "is invalid without a title" do
    expect(build(:program_day, title: nil)).not_to be_valid
  end

  it "is destroyed along with its workout program" do
    day = create(:program_day)
    program = day.workout_program

    expect { program.destroy }.to change(ProgramDay, :count).by(-1)
  end

  it "is destroyed along with its workout_sessions" do
    day = create(:program_day)
    create(:workout_session, workout_program: day.workout_program, program_day: day)

    expect { day.destroy }.to change(WorkoutSession, :count).by(-1)
  end
end
