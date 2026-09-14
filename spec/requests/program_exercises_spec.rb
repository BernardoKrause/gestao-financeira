require "rails_helper"

RSpec.describe "ProgramExercises", type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:workout_program, user: user) }
  let(:day) { create(:program_day, workout_program: program) }

  before { sign_in user }

  it "adds a strength exercise to a day with default targets" do
    exercise = create(:exercise, kind: :strength)

    expect {
      post workout_program_program_day_program_exercises_path(program, day), params: { exercise_id: exercise.id }
    }.to change(day.program_exercises, :count).by(1)

    program_exercise = day.program_exercises.last
    expect(program_exercise.target_sets).to eq(3)
    expect(program_exercise.target_reps).to eq(10)
    expect(response).to redirect_to(edit_workout_program_path(program))
  end

  it "adds a cardio exercise to a day with a default duration" do
    exercise = create(:exercise, :cardio)

    post workout_program_program_day_program_exercises_path(program, day), params: { exercise_id: exercise.id }

    program_exercise = day.program_exercises.last
    expect(program_exercise.target_duration_minutes).to eq(20)
    expect(program_exercise.target_sets).to be_nil
  end

  it "returns 404 when trying to add another user's custom exercise" do
    other_exercise = create(:exercise, :custom)

    expect {
      post workout_program_program_day_program_exercises_path(program, day), params: { exercise_id: other_exercise.id }
    }.not_to change(ProgramExercise, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "updates target sets and reps" do
    program_exercise = create(:program_exercise, program_day: day)
    patch workout_program_program_day_program_exercise_path(program, day, program_exercise),
      params: { program_exercise: { target_sets: 5, target_reps: 8 } }

    expect(program_exercise.reload.target_sets).to eq(5)
    expect(program_exercise.target_reps).to eq(8)
  end

  it "removes an exercise from a day" do
    program_exercise = create(:program_exercise, program_day: day)
    expect { delete workout_program_program_day_program_exercise_path(program, day, program_exercise) }
      .to change(ProgramExercise, :count).by(-1)
  end

  it "reorders exercises within a day" do
    first = create(:program_exercise, program_day: day, position: 0)
    second = create(:program_exercise, program_day: day, position: 1)

    patch reorder_workout_program_program_day_program_exercises_path(program, day),
      params: { ids: [ second.id, first.id ] }, as: :json

    expect(second.reload.position).to eq(0)
    expect(first.reload.position).to eq(1)
  end
end
