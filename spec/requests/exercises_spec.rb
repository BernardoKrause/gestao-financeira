require "rails_helper"

RSpec.describe "Exercises", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "lists global exercises and the user's own custom exercises, but not other users'" do
    global = create(:exercise, name: "Supino Reto")
    mine = create(:exercise, :custom, user: user, name: "Meu Exercício")
    other = create(:exercise, :custom, name: "Exercício de outro usuário")

    get exercises_path

    expect(response.body).to include(global.name)
    expect(response.body).to include(mine.name)
    expect(response.body).not_to include(other.name)
  end

  it "filters by muscle group" do
    chest = create(:exercise, name: "Supino", muscle_group: :chest)
    legs = create(:exercise, name: "Agachamento", muscle_group: :legs)

    get exercises_path, params: { muscle_group: "legs" }

    expect(response.body).to include(legs.name)
    expect(response.body).not_to include(chest.name)
  end

  it "filters via turbo_stream, for live filtering, without a full page reload" do
    chest = create(:exercise, name: "Supino", muscle_group: :chest)
    legs = create(:exercise, name: "Agachamento", muscle_group: :legs)

    get exercises_path, params: { muscle_group: "legs" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response.media_type).to eq(Mime[:turbo_stream])
    expect(response.body).to include(legs.name)
    expect(response.body).not_to include(chest.name)
  end

  it "preserves workout_program and program_day context when filtering via turbo_stream" do
    program = create(:workout_program, user: user)
    day = create(:program_day, workout_program: program)
    exercise = create(:exercise, name: "Supino", muscle_group: :chest)

    get exercises_path(workout_program_id: program.id, program_day_id: day.id),
      params: { muscle_group: "chest" },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response.media_type).to eq(Mime[:turbo_stream])
    expect(response.body).to include(exercise.name)
    expect(response.body).to include("Adicionar a esta ficha")
  end

  it "creates a custom exercise owned by the current user" do
    expect {
      post exercises_path, params: { exercise: { name: "Rosca Direta", muscle_group: "biceps", kind: "strength" } }
    }.to change(Exercise, :count).by(1)

    expect(response).to redirect_to(exercises_path(format: :html))
    expect(Exercise.last.user).to eq(user)
  end

  it "does not create an exercise without a name" do
    expect {
      post exercises_path, params: { exercise: { name: "", muscle_group: "chest", kind: "strength" } }
    }.not_to change(Exercise, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "returns to the day-scoped picker after creating an exercise from within a program day" do
    program = create(:workout_program, user: user)
    day = create(:program_day, workout_program: program)

    post exercises_path(workout_program_id: program.id, program_day_id: day.id),
      params: { exercise: { name: "Rosca Direta", muscle_group: "biceps", kind: "strength" } }

    expect(response).to redirect_to(exercises_path(format: :html, workout_program_id: program.id, program_day_id: day.id))
  end

  it "redirects to an html response even when Turbo's redirect-following request still prefers turbo_stream" do
    program = create(:workout_program, user: user)
    day = create(:program_day, workout_program: program)
    turbo_accept = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"

    post exercises_path(workout_program_id: program.id, program_day_id: day.id),
      params: { exercise: { name: "Rosca Direta", muscle_group: "biceps", kind: "strength" } },
      headers: { "Accept" => turbo_accept }

    get response.location, headers: { "Accept" => turbo_accept }

    expect(response.media_type).to eq("text/html")
  end

  it "returns 404 when creating an exercise scoped to another user's program" do
    other_program = create(:workout_program)
    other_day = create(:program_day, workout_program: other_program)

    expect {
      post exercises_path(workout_program_id: other_program.id, program_day_id: other_day.id),
        params: { exercise: { name: "X", muscle_group: "chest", kind: "strength" } }
    }.not_to change(Exercise, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "shows the day-scoped 'add to program' form when opened from a program day" do
    program = create(:workout_program, user: user)
    day = create(:program_day, workout_program: program)

    get new_exercise_path(workout_program_id: program.id, program_day_id: day.id)

    expect(response).to have_http_status(:ok)
  end

  it "updates the user's own custom exercise" do
    exercise = create(:exercise, :custom, user: user, name: "Nome antigo")
    patch exercise_path(exercise), params: { exercise: { name: "Nome novo" } }
    expect(exercise.reload.name).to eq("Nome novo")
  end

  it "destroys the user's own custom exercise" do
    exercise = create(:exercise, :custom, user: user)
    expect { delete exercise_path(exercise) }.to change(Exercise, :count).by(-1)
  end

  it "does not destroy a custom exercise that is used in a program, and shows an error" do
    exercise = create(:exercise, :custom, user: user)
    create(:program_exercise, exercise: exercise)

    expect { delete exercise_path(exercise) }.not_to change(Exercise, :count)
    expect(response).to redirect_to(exercises_path)
    expect(flash[:alert]).to be_present
  end

  it "returns 404 when trying to edit a global exercise" do
    global = create(:exercise)
    get edit_exercise_path(global)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when trying to edit another user's custom exercise" do
    other = create(:exercise, :custom)
    get edit_exercise_path(other)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when trying to destroy a global exercise" do
    global = create(:exercise)
    expect { delete exercise_path(global) }.not_to change(Exercise, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "shows an 'add to program' action when opened as a picker for a program day" do
    program = create(:workout_program, user: user)
    day = create(:program_day, workout_program: program)
    create(:exercise, name: "Supino Reto")

    get exercises_path(workout_program_id: program.id, program_day_id: day.id)

    expect(response.body).to include("Adicionar a esta ficha")
  end
end
