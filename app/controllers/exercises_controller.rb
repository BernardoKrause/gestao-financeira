class ExercisesController < ApplicationController
  before_action :set_own_exercise, only: %i[edit update destroy]
  before_action :load_program_context, only: %i[index new create]

  def index
    @exercises = Exercise.visible_to(current_user).order(:name)
    @exercises = @exercises.where(muscle_group: params[:muscle_group]) if params[:muscle_group].present?
    @exercises = @exercises.where(kind: params[:kind]) if params[:kind].present?
    @exercises = @exercises.where("name ILIKE ?", "%#{params[:query]}%") if params[:query].present?
  end

  def new
    @exercise = current_user.exercises.new
  end

  def edit; end

  def create
    @exercise = current_user.exercises.new(exercise_params)
    if @exercise.save
      destination = @workout_program ? exercises_path(format: :html, workout_program_id: @workout_program.id, program_day_id: @program_day.id) : exercises_path(format: :html)
      redirect_to destination, notice: "Exercício criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @exercise.update(exercise_params)
      redirect_to exercises_path, notice: "Exercício atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @exercise.destroy
      redirect_to exercises_path, notice: "Exercício removido."
    else
      redirect_to exercises_path, alert: @exercise.errors.full_messages.to_sentence
    end
  end

  private

  def load_program_context
    return unless params[:workout_program_id].present?

    @workout_program = current_user.workout_programs.find(params[:workout_program_id])
    @program_day = @workout_program.program_days.find(params[:program_day_id])
    @added_exercise_ids = @program_day.program_exercises.pluck(:exercise_id).to_set
  end

  def set_own_exercise
    @exercise = current_user.exercises.find(params[:id])
  end

  def exercise_params
    params.require(:exercise).permit(:name, :muscle_group, :kind, :notes)
  end
end
