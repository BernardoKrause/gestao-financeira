class WorkoutProgramsController < ApplicationController
  before_action :set_workout_program, only: %i[edit update destroy activate duplicate]

  def index
    @workout_programs = current_user.workout_programs.order(:name)
    @active_workout_program = current_user.workout_programs.find_by(active: true)
  end

  def new
    @workout_program = current_user.workout_programs.new
  end

  def create
    @workout_program = current_user.workout_programs.new(workout_program_params)
    if @workout_program.save
      redirect_to edit_workout_program_path(@workout_program), notice: "Ficha criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @program_days = @workout_program.program_days.includes(program_exercises: :exercise)
  end

  def update
    if @workout_program.update(workout_program_params)
      redirect_to edit_workout_program_path(@workout_program), notice: "Ficha atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workout_program.destroy
    redirect_to workout_programs_path, notice: "Ficha removida."
  end

  def activate
    @workout_program.activate!
    redirect_to workout_programs_path, notice: "Ficha \"#{@workout_program.name}\" ativada."
  end

  def duplicate
    copy = WorkoutProgramDuplicator.call(@workout_program)
    redirect_to workout_programs_path, notice: "Ficha duplicada como \"#{copy.name}\"."
  end

  private

  def set_workout_program
    @workout_program = current_user.workout_programs.find(params[:id])
  end

  def workout_program_params
    params.require(:workout_program).permit(:name)
  end
end
