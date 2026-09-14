require "rails_helper"

RSpec.describe "WorkoutPrograms", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "creates a workout program and redirects to its builder page" do
    expect {
      post workout_programs_path, params: { workout_program: { name: "Ficha ABCD" } }
    }.to change(WorkoutProgram, :count).by(1)

    expect(response).to redirect_to(edit_workout_program_path(WorkoutProgram.last))
  end

  it "does not create a workout program without a name" do
    expect {
      post workout_programs_path, params: { workout_program: { name: "" } }
    }.not_to change(WorkoutProgram, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates a workout program's name" do
    program = create(:workout_program, user: user, name: "Nome antigo")
    patch workout_program_path(program), params: { workout_program: { name: "Nome novo" } }
    expect(program.reload.name).to eq("Nome novo")
  end

  it "destroys a workout program" do
    program = create(:workout_program, user: user)
    expect { delete workout_program_path(program) }.to change(WorkoutProgram, :count).by(-1)
  end

  it "activates a program and deactivates the previously active one" do
    current = create(:workout_program, user: user, active: true)
    target = create(:workout_program, user: user, active: false)

    post activate_workout_program_path(target)

    expect(target.reload.active).to be true
    expect(current.reload.active).to be false
    expect(response).to redirect_to(workout_programs_path)
  end

  it "duplicates a program" do
    program = create(:workout_program, user: user, name: "Ficha ABCD")

    expect {
      post duplicate_workout_program_path(program)
    }.to change(WorkoutProgram, :count).by(1)

    expect(WorkoutProgram.last.name).to eq("Ficha ABCD (cópia)")
  end

  it "returns 404 when trying to edit another user's workout program" do
    other_program = create(:workout_program)
    get edit_workout_program_path(other_program)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when trying to update another user's workout program" do
    other_program = create(:workout_program)
    patch workout_program_path(other_program), params: { workout_program: { name: "Hackeado" } }
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when trying to activate another user's workout program" do
    other_program = create(:workout_program)
    post activate_workout_program_path(other_program)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when trying to destroy another user's workout program" do
    other_program = create(:workout_program)
    expect { delete workout_program_path(other_program) }.not_to change(WorkoutProgram, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "shows the active program banner on the index page" do
    create(:workout_program, user: user, name: "Ficha Ativa", active: true)

    get workout_programs_path

    expect(response.body).to include("Ficha ativa")
    expect(response.body).to include("Ficha Ativa")
  end
end
