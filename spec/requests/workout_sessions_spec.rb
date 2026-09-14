require "rails_helper"

RSpec.describe "WorkoutSessions", type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:workout_program, user: user, active: true) }
  let!(:day_a) { create(:program_day, workout_program: program, label: "A", position: 0) }
  let!(:day_b) { create(:program_day, workout_program: program, label: "B", position: 1) }

  before { sign_in user }

  describe "GET /treinos/workout_session/new" do
    it "suggests the first day when there is no history" do
      get new_workout_session_path

      expect(response.body).to include("Sugerido")
      expect(response.body).to match(/Treino A.*Sugerido/m)
    end

    it "suggests the next day after the most recently completed session" do
      create(:workout_session, :completed, workout_program: program, program_day: day_a, user: user, finished_at: 1.day.ago)

      get new_workout_session_path

      expect(response.body).to match(/Treino B.*Sugerido/m)
    end

    it "wraps around to the first day after the last one" do
      create(:workout_session, :completed, workout_program: program, program_day: day_b, user: user, finished_at: 1.day.ago)

      get new_workout_session_path

      expect(response.body).to match(/Treino A.*Sugerido/m)
    end

    it "redirects to Fichas when there is no active program" do
      program.update!(active: false)

      get new_workout_session_path

      expect(response).to redirect_to(workout_programs_path)
    end

    it "redirects to Fichas when the active ficha has no days yet" do
      program.program_days.destroy_all

      get new_workout_session_path

      expect(response).to redirect_to(workout_programs_path)
    end

    it "redirects to the existing session when one is already in progress" do
      session = create(:workout_session, workout_program: program, program_day: day_a, user: user)

      get new_workout_session_path

      expect(response).to redirect_to(workout_session_path)
      expect(WorkoutSession.count).to eq(1)
      expect(session.reload).to be_in_progress
    end
  end

  describe "POST /treinos/workout_session" do
    it "creates a session and pre-generates set_logs from the day's targets" do
      exercise = create(:exercise, kind: :strength)
      create(:program_exercise, program_day: day_a, exercise: exercise, target_sets: 3, target_reps: 12)

      expect {
        post workout_session_path, params: { program_day_id: day_a.id }
      }.to change(WorkoutSession, :count).by(1)

      session = WorkoutSession.last
      expect(response).to redirect_to(workout_session_path)
      expect(session.program_day).to eq(day_a)
      expect(session.set_logs.count).to eq(3)
      expect(session.set_logs.pluck(:reps)).to all(eq(12))
      expect(session.set_logs.pluck(:weight_kg)).to all(be_nil)
    end

    it "pre-generates a single set_log for a cardio exercise" do
      exercise = create(:exercise, :cardio)
      create(:program_exercise, :cardio, program_day: day_a, exercise: exercise, target_duration_minutes: 25)

      post workout_session_path, params: { program_day_id: day_a.id }

      set_log = WorkoutSession.last.set_logs.sole
      expect(set_log.duration_minutes).to eq(25)
      expect(set_log.reps).to be_nil
    end

    it "does not create a second session when one is already in progress" do
      create(:workout_session, workout_program: program, program_day: day_a, user: user)

      expect {
        post workout_session_path, params: { program_day_id: day_b.id }
      }.not_to change(WorkoutSession, :count)

      expect(response).to redirect_to(workout_session_path)
    end
  end

  describe "GET /treinos/workout_session" do
    it "shows the in-progress session" do
      session = create(:workout_session, workout_program: program, program_day: day_a, user: user)

      get workout_session_path

      expect(response.body).to include("Treino A")
      expect(session.reload).to be_in_progress
    end

    it "redirects to Fichas when there is no session in progress" do
      get workout_session_path

      expect(response).to redirect_to(workout_programs_path)
    end

    it "renders the exercise grid with pre-generated set_logs" do
      exercise = create(:exercise, kind: :strength)
      program_exercise = create(:program_exercise, program_day: day_a, exercise: exercise, target_sets: 2, target_reps: 10)
      session = create(:workout_session, workout_program: program, program_day: day_a, user: user)
      create(:set_log, workout_session: session, program_exercise: program_exercise, position: 0)
      create(:set_log, workout_session: session, program_exercise: program_exercise, position: 1)

      get workout_session_path

      expect(response.body).to include(exercise.name)
      expect(response.body).to include("Adicionar Série")
    end

    it "renders a cardio exercise with a single duration field, not reps/weight" do
      cardio_exercise = create(:exercise, :cardio)
      cardio_program_exercise = create(:program_exercise, :cardio, program_day: day_a, exercise: cardio_exercise, target_duration_minutes: 20)
      session = create(:workout_session, workout_program: program, program_day: day_a, user: user)
      create(:set_log, :cardio, workout_session: session, program_exercise: cardio_program_exercise, position: 0)

      get workout_session_path

      expect(response.body).to include(cardio_exercise.name)
      expect(response.body).to include("min")
    end

    it "renders the Finalizar Treino button targeting PATCH" do
      create(:workout_session, workout_program: program, program_day: day_a, user: user)

      get workout_session_path

      expect(response.body).to include(%(action="#{finish_workout_session_path}"))
      expect(response.body).to match(/name="_method" value="patch"/)
    end
  end

  describe "PATCH /treinos/workout_session/finish" do
    it "marks the session completed and redirects to the summary" do
      exercise = create(:exercise, kind: :strength)
      program_exercise = create(:program_exercise, program_day: day_a, exercise: exercise, target_sets: 1, target_reps: 10)
      session = create(:workout_session, workout_program: program, program_day: day_a, user: user)
      create(:set_log, :completed, workout_session: session, program_exercise: program_exercise, reps: 10, weight_kg: 60)

      patch finish_workout_session_path

      expect(session.reload).to be_completed
      expect(session.finished_at).to be_present
      expect(response).to redirect_to(summary_workout_session_path)
    end

    it "redirects to Fichas when there is no session in progress" do
      patch finish_workout_session_path

      expect(response).to redirect_to(workout_programs_path)
    end
  end

  describe "GET /treinos/workout_session/summary" do
    it "renders the completed session's summary" do
      exercise = create(:exercise, kind: :strength)
      program_exercise = create(:program_exercise, program_day: day_a, exercise: exercise, target_sets: 1, target_reps: 10)
      session = create(:workout_session, :completed, workout_program: program, program_day: day_a, user: user)
      create(:set_log, :completed, workout_session: session, program_exercise: program_exercise, reps: 10, weight_kg: 60)

      get summary_workout_session_path

      expect(response.body).to include("Treino Concluído")
      expect(response.body).to include("10 reps × 60.0 kg")
    end

    it "redirects to Fichas when there is no completed session to show" do
      get summary_workout_session_path

      expect(response).to redirect_to(workout_programs_path)
    end
  end

  describe "DELETE /treinos/workout_session" do
    it "cancels the session and destroys its set_logs" do
      session = create(:workout_session, workout_program: program, program_day: day_a, user: user)
      create(:set_log, workout_session: session, program_exercise: create(:program_exercise, program_day: day_a))

      expect { delete workout_session_path }.to change(WorkoutSession, :count).by(-1).and change(SetLog, :count).by(-1)
      expect(response).to redirect_to(workout_programs_path)
    end

    it "redirects to Fichas when there is no session in progress" do
      delete workout_session_path

      expect(response).to redirect_to(workout_programs_path)
    end
  end
end
