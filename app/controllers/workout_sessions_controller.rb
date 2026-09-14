class WorkoutSessionsController < ApplicationController
  before_action :redirect_if_no_active_program, only: %i[new create]
  before_action :redirect_to_existing_session, only: %i[new create]

  def new
    @program_days = @workout_program.program_days.order(:position)

    if @program_days.empty?
      redirect_to workout_programs_path, alert: "Esta ficha não tem nenhum dia cadastrado ainda."
      return
    end

    @suggested_program_day = suggested_program_day
  end

  def create
    program_day = @workout_program.program_days.find(params[:program_day_id])

    @workout_session = current_user.workout_sessions.new(
      workout_program: @workout_program,
      program_day: program_day,
      started_at: Time.current
    )

    if @workout_session.save
      generate_set_logs(@workout_session, program_day)
      redirect_to workout_session_path, notice: "Treino iniciado!"
    else
      redirect_to workout_programs_path, alert: "Não foi possível iniciar o treino."
    end
  end

  def show
    @workout_session = current_user.workout_sessions.find_by(status: :in_progress)

    if @workout_session.nil?
      redirect_to workout_programs_path, alert: "Nenhum treino em andamento."
      return
    end

    @program_exercises = @workout_session.program_day.program_exercises.includes(:exercise).order(:position)
    @set_logs_by_program_exercise = @workout_session.set_logs.includes(program_exercise: :exercise).order(:position).group_by(&:program_exercise_id)
  end

  def finish
    @workout_session = current_user.workout_sessions.find_by(status: :in_progress)

    if @workout_session.nil?
      redirect_to workout_programs_path, alert: "Nenhum treino em andamento."
      return
    end

    @workout_session.update!(status: :completed, finished_at: Time.current)
    redirect_to summary_workout_session_path
  end

  def summary
    @workout_session = current_user.workout_sessions.where(status: :completed).order(finished_at: :desc).first

    if @workout_session.nil?
      redirect_to workout_programs_path, alert: "Nenhum treino concluído para mostrar."
      return
    end

    @program_exercises = @workout_session.program_day.program_exercises.includes(:exercise).order(:position)
    @set_logs_by_program_exercise = @workout_session.set_logs.includes(program_exercise: :exercise).order(:position).group_by(&:program_exercise_id)
  end

  def destroy
    @workout_session = current_user.workout_sessions.find_by(status: :in_progress)

    if @workout_session
      @workout_session.destroy
      redirect_to workout_programs_path, notice: "Treino cancelado."
    else
      redirect_to workout_programs_path, alert: "Nenhum treino em andamento."
    end
  end

  private

  def redirect_if_no_active_program
    @workout_program = current_user.workout_programs.find_by(active: true)

    if @workout_program.nil?
      redirect_to workout_programs_path, alert: "Nenhuma ficha ativa. Ative uma ficha antes de iniciar um treino."
    end
  end

  def redirect_to_existing_session
    redirect_to workout_session_path if current_user.workout_sessions.exists?(status: :in_progress)
  end

  def suggested_program_day
    days = @program_days.to_a
    last_completed = current_user.workout_sessions
      .where(workout_program: @workout_program, status: :completed)
      .order(finished_at: :desc)
      .first

    return days.first if last_completed.nil?

    last_index = days.index { |day| day.id == last_completed.program_day_id }
    return days.first if last_index.nil?

    days[(last_index + 1) % days.length]
  end

  def generate_set_logs(workout_session, program_day)
    program_day.program_exercises.includes(:exercise).order(:position).each do |program_exercise|
      exercise = program_exercise.exercise
      count = exercise.cardio? ? 1 : program_exercise.target_sets

      count.times do |index|
        workout_session.set_logs.create!(
          program_exercise: program_exercise,
          position: index,
          reps: exercise.strength? ? program_exercise.target_reps : nil,
          duration_minutes: exercise.cardio? ? program_exercise.target_duration_minutes : nil
        )
      end
    end
  end
end
