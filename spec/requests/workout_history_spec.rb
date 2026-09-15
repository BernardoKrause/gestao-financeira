require "rails_helper"

RSpec.describe "WorkoutHistory", type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:workout_program, user: user, active: true) }
  let!(:day_a) { create(:program_day, workout_program: program, label: "A", position: 0) }

  before { sign_in user }

  describe "GET /treinos/historico" do
    it "marks a day with a completed workout session in the current month" do
      travel_to Date.new(2026, 9, 15) do
        create(:workout_session, :completed, workout_program: program, program_day: day_a, user: user, finished_at: Time.zone.local(2026, 9, 10, 12, 0))

        get workout_history_path

        expect(response.body).to include(workout_history_day_path(date: "2026-09-10"))
      end
    end

    it "does not mark a day without a completed session" do
      travel_to Date.new(2026, 9, 15) do
        get workout_history_path

        expect(response.body).not_to include(workout_history_day_path(date: "2026-09-01"))
      end
    end

    it "navigates to a different month via the month param" do
      create(:workout_session, :completed, workout_program: program, program_day: day_a, user: user, finished_at: Time.zone.local(2026, 8, 5, 12, 0))

      get workout_history_path, params: { month: "2026-08" }

      expect(response.body).to include(workout_history_day_path(date: "2026-08-05"))
      expect(response.body).to include("Agosto de 2026")
    end

    it "defaults the exercise dropdown to the most recently logged strength exercise" do
      exercise_a = create(:exercise, kind: :strength, name: "Supino")
      exercise_b = create(:exercise, kind: :strength, name: "Agachamento")
      program_exercise_a = create(:program_exercise, program_day: day_a, exercise: exercise_a)
      program_exercise_b = create(:program_exercise, program_day: day_a, exercise: exercise_b)
      older_session = create(:workout_session, :completed, workout_program: program, program_day: day_a, user: user, finished_at: 10.days.ago)
      newer_session = create(:workout_session, :completed, workout_program: program, program_day: day_a, user: user, finished_at: 1.day.ago)
      create(:set_log, :completed, workout_session: older_session, program_exercise: program_exercise_a, weight_kg: 60)
      create(:set_log, :completed, workout_session: newer_session, program_exercise: program_exercise_b, weight_kg: 80)

      get workout_history_path

      selected_option = Nokogiri::HTML::DocumentFragment.parse(response.body).at_css("select#exercise_id option[selected]")
      expect(selected_option["value"]).to eq(exercise_b.id.to_s)
      expect(selected_option.text).to eq("Agachamento")
    end

    it "shows an empty-state message when there is no strength history yet" do
      get workout_history_path

      expect(response.body).to include("Registre cargas em pelo menos um treino")
    end

    it "excludes exercises with only incomplete or weightless set_logs from the dropdown" do
      exercise = create(:exercise, kind: :strength, name: "Levantamento Terra")
      program_exercise = create(:program_exercise, program_day: day_a, exercise: exercise)
      session = create(:workout_session, :completed, workout_program: program, program_day: day_a, user: user)
      create(:set_log, workout_session: session, program_exercise: program_exercise, weight_kg: 60, completed: false)

      get workout_history_path

      expect(response.body).not_to include("Levantamento Terra")
    end
  end

  describe "GET /treinos/historico/grafico" do
    it "returns a turbo stream replacing the chart with the selected exercise's series" do
      exercise = create(:exercise, kind: :strength, name: "Supino")
      program_exercise = create(:program_exercise, program_day: day_a, exercise: exercise)
      session = create(:workout_session, :completed, workout_program: program, program_day: day_a, user: user, finished_at: 2.days.ago)
      create(:set_log, :completed, workout_session: session, program_exercise: program_exercise, weight_kg: 72.5)

      get workout_history_chart_path, params: { exercise_id: exercise.id, period: "3m" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('turbo-stream action="replace" target="workout_progress_chart"')
      expect(response.body).to include("72.5")
    end

    it "excludes set_logs outside the selected period" do
      exercise = create(:exercise, kind: :strength)
      program_exercise = create(:program_exercise, program_day: day_a, exercise: exercise)
      old_session = create(:workout_session, :completed, workout_program: program, program_day: day_a, user: user, finished_at: 2.months.ago)
      create(:set_log, :completed, workout_session: old_session, program_exercise: program_exercise, weight_kg: 99)

      get workout_history_chart_path, params: { exercise_id: exercise.id, period: "1m" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).not_to include("99.0")
    end
  end
end
