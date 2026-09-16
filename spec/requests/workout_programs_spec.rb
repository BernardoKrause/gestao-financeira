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

  describe "GET /treinos" do
    it "does not show the streak card without an active program" do
      get workout_programs_path

      expect(response.body).not_to include("semana seguida")
      expect(response.body).not_to include("Comece sua sequência!")
    end

    it "shows the streak card with weekly progress once a program is active" do
      program = create(:workout_program, user: user, active: true)
      create(:program_day, workout_program: program)

      get workout_programs_path

      expect(response.body).to include("Comece sua sequência!")
      expect(response.body).to include("Esta semana: 0/1 treinos")
    end

    it "shows the current streak count and unlocked badges" do
      program = create(:workout_program, user: user, active: true)
      day = create(:program_day, workout_program: program)
      [ 4, 3, 2, 1, 0 ].each do |weeks_ago|
        create(:workout_session, :completed, workout_program: program, program_day: day, user: user, finished_at: weeks_ago.weeks.ago)
      end

      get workout_programs_path

      expect(response.body).to include("5 semanas seguidas")
      expect(response.body).to include("🏅 4 semanas")
    end
  end
end
