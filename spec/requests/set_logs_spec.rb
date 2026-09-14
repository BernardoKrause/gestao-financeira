require "rails_helper"

RSpec.describe "SetLogs", type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:workout_program, user: user, active: true) }
  let(:day) { create(:program_day, workout_program: program) }
  let(:exercise) { create(:exercise, kind: :strength) }
  let(:program_exercise) { create(:program_exercise, program_day: day, exercise: exercise, target_sets: 2, target_reps: 10) }
  let!(:session) { create(:workout_session, workout_program: program, program_day: day, user: user) }

  before { sign_in user }

  describe "POST /treinos/workout_session/set_logs" do
    it "adds an extra set to the exercise, defaulting to its target reps" do
      create(:set_log, workout_session: session, program_exercise: program_exercise, position: 0)

      expect {
        post workout_session_set_logs_path(program_exercise_id: program_exercise.id)
      }.to change(session.set_logs, :count).by(1)

      new_set_log = session.set_logs.order(:position).last
      expect(new_set_log.position).to eq(1)
      expect(new_set_log.reps).to eq(10)
      expect(response).to redirect_to(workout_session_path)
    end

    it "returns 404 for a program_exercise from another day" do
      other_day_exercise = create(:program_exercise)

      expect {
        post workout_session_set_logs_path(program_exercise_id: other_day_exercise.id)
      }.not_to change(SetLog, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "adds an extra cardio set, defaulting to its target duration" do
      cardio_exercise = create(:exercise, :cardio)
      cardio_program_exercise = create(:program_exercise, :cardio, program_day: day, exercise: cardio_exercise, target_duration_minutes: 25)
      create(:set_log, :cardio, workout_session: session, program_exercise: cardio_program_exercise, position: 0)

      expect {
        post workout_session_set_logs_path(program_exercise_id: cardio_program_exercise.id)
      }.to change(session.set_logs, :count).by(1)

      new_set_log = session.set_logs.where(program_exercise: cardio_program_exercise).order(:position).last
      expect(new_set_log.duration_minutes).to eq(25)
      expect(new_set_log.reps).to be_nil
    end
  end

  describe "PATCH /treinos/workout_session/set_logs/:id" do
    it "updates reps and weight_kg and marks it completed via turbo_stream" do
      set_log = create(:set_log, workout_session: session, program_exercise: program_exercise, reps: 10, weight_kg: nil, completed: false)

      patch workout_session_set_log_path(set_log),
        params: { set_log: { reps: 12, weight_kg: 82.5, completed: true } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="#{ActionView::RecordIdentifier.dom_id(set_log)}"))
      set_log.reload
      expect(set_log.reps).to eq(12)
      expect(set_log.weight_kg).to eq(82.5)
      expect(set_log).to be_completed
    end

    it "returns 404 when updating a set_log from another user's session" do
      other_set_log = create(:set_log)

      patch workout_session_set_log_path(other_set_log), params: { set_log: { reps: 5 } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /treinos/workout_session/set_logs/:id" do
    it "removes the set" do
      set_log = create(:set_log, workout_session: session, program_exercise: program_exercise)

      expect { delete workout_session_set_log_path(set_log) }.to change(SetLog, :count).by(-1)
      expect(response).to redirect_to(workout_session_path)
    end

    it "returns 404 when destroying a set_log from another user's session" do
      other_set_log = create(:set_log)

      expect { delete workout_session_set_log_path(other_set_log) }.not_to change(SetLog, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
