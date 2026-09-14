class ExercisesController < ApplicationController
  before_action :set_own_exercise, only: %i[edit update destroy]

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
      redirect_to exercises_path, notice: "Exercício criado com sucesso."
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

  def set_own_exercise
    @exercise = current_user.exercises.find(params[:id])
  end

  def exercise_params
    params.require(:exercise).permit(:name, :muscle_group, :kind, :notes)
  end
end
