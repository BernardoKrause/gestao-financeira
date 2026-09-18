class ProgramExercisesController < ApplicationController
  before_action :set_workout_program
  before_action :set_program_day
  before_action :set_program_exercise, only: %i[update destroy]

  def create
    exercise = Exercise.visible_to(current_user).find(params[:exercise_id])
    @program_exercise = @program_day.program_exercises.new(
      exercise: exercise,
      position: @program_day.program_exercises.maximum(:position).to_i + 1,
      **default_targets_for(exercise)
    )

    if @program_exercise.save
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "#{exercise.name} adicionado à ficha." }
        format.html { redirect_to edit_workout_program_path(@workout_program), notice: "#{exercise.name} adicionado à ficha." }
      end
    else
      respond_to do |format|
        format.turbo_stream { flash.now[:alert] = @program_exercise.errors.full_messages.to_sentence }
        format.html { redirect_to edit_workout_program_path(@workout_program), alert: @program_exercise.errors.full_messages.to_sentence }
      end
    end
  end

  def update
    if @program_exercise.update(program_exercise_params)
      redirect_to edit_workout_program_path(@workout_program), notice: "Meta atualizada."
    else
      redirect_to edit_workout_program_path(@workout_program), alert: @program_exercise.errors.full_messages.to_sentence
    end
  end

  def destroy
    @program_exercise.destroy
    redirect_to edit_workout_program_path(@workout_program), notice: "Exercício removido da ficha."
  end

  def reorder
    params[:ids].each_with_index do |id, index|
      @program_day.program_exercises.where(id: id).update_all(position: index)
    end
    head :no_content
  end

  private

  def set_workout_program
    @workout_program = current_user.workout_programs.find(params[:workout_program_id])
  end

  def set_program_day
    @program_day = @workout_program.program_days.find(params[:program_day_id])
  end

  def set_program_exercise
    @program_exercise = @program_day.program_exercises.find(params[:id])
  end

  def default_targets_for(exercise)
    if exercise.strength?
      { target_sets: 3, target_reps: 10 }
    elsif exercise.cardio?
      { target_duration_minutes: 20 }
    else
      {}
    end
  end

  def program_exercise_params
    params.require(:program_exercise).permit(:target_sets, :target_reps, :target_duration_minutes)
  end
end
