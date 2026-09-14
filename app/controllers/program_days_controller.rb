class ProgramDaysController < ApplicationController
  before_action :set_workout_program
  before_action :set_program_day, only: %i[destroy]

  def create
    @program_day = @workout_program.program_days.new(program_day_params)
    @program_day.position = @workout_program.program_days.maximum(:position).to_i + 1

    if @program_day.save
      redirect_to edit_workout_program_path(@workout_program), notice: "Dia adicionado com sucesso."
    else
      redirect_to edit_workout_program_path(@workout_program), alert: @program_day.errors.full_messages.to_sentence
    end
  end

  def destroy
    @program_day.destroy
    redirect_to edit_workout_program_path(@workout_program), notice: "Dia removido."
  end

  def reorder
    params[:ids].each_with_index do |id, index|
      @workout_program.program_days.where(id: id).update_all(position: index)
    end
    head :no_content
  end

  private

  def set_workout_program
    @workout_program = current_user.workout_programs.find(params[:workout_program_id])
  end

  def set_program_day
    @program_day = @workout_program.program_days.find(params[:id])
  end

  def program_day_params
    params.require(:program_day).permit(:label, :title)
  end
end
