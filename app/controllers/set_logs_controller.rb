class SetLogsController < ApplicationController
  before_action :set_workout_session
  before_action :set_set_log, only: %i[update destroy]

  def create
    program_exercise = @workout_session.program_day.program_exercises.find(params[:program_exercise_id])
    exercise = program_exercise.exercise
    next_position = (@workout_session.set_logs.where(program_exercise: program_exercise).maximum(:position) || -1) + 1

    @workout_session.set_logs.create(
      program_exercise: program_exercise,
      position: next_position,
      reps: exercise.strength? ? program_exercise.target_reps : nil,
      duration_minutes: exercise.cardio? ? program_exercise.target_duration_minutes : nil
    )

    redirect_to workout_session_path, notice: "Série adicionada."
  end

  def update
    @set_log.update(set_log_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to workout_session_path }
    end
  end

  def destroy
    @set_log.destroy
    redirect_to workout_session_path, notice: "Série removida."
  end

  private

  def set_workout_session
    @workout_session = current_user.workout_sessions.find_by(status: :in_progress)
    redirect_to workout_programs_path, alert: "Nenhum treino em andamento." if @workout_session.nil?
  end

  def set_set_log
    @set_log = @workout_session.set_logs.find(params[:id])
  end

  def set_log_params
    params.require(:set_log).permit(:reps, :weight_kg, :duration_minutes, :completed)
  end
end
