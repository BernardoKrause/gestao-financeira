require "rails_helper"

RSpec.describe WorkoutProgramDuplicator do
  it "creates an inactive copy with the same days and exercises" do
    program = create(:workout_program, name: "Ficha ABCD", active: true)
    day = create(:program_day, workout_program: program, label: "A", title: "Peito", position: 0)
    exercise = create(:exercise)
    create(:program_exercise, program_day: day, exercise: exercise, position: 0, target_sets: 4, target_reps: 10)

    copy = described_class.call(program)

    expect(copy).to be_persisted
    expect(copy.user).to eq(program.user)
    expect(copy.name).to eq("Ficha ABCD (cópia)")
    expect(copy.active).to be false

    copy_day = copy.program_days.sole
    expect(copy_day.label).to eq("A")
    expect(copy_day.title).to eq("Peito")

    copy_exercise = copy_day.program_exercises.sole
    expect(copy_exercise.exercise).to eq(exercise)
    expect(copy_exercise.target_sets).to eq(4)
    expect(copy_exercise.target_reps).to eq(10)
  end

  it "does not mutate the original program" do
    program = create(:workout_program)
    create(:program_day, workout_program: program)

    expect { described_class.call(program) }.to change(WorkoutProgram, :count).by(1)
    expect(program.reload.program_days.count).to eq(1)
  end
end
