class WorkoutProgramDuplicator
  def self.call(workout_program)
    new(workout_program).call
  end

  def initialize(workout_program)
    @source = workout_program
  end

  def call
    ActiveRecord::Base.transaction do
      copy = source.user.workout_programs.create!(name: "#{source.name} (cópia)", active: false)

      source.program_days.each do |day|
        new_day = copy.program_days.create!(label: day.label, title: day.title, position: day.position)

        day.program_exercises.each do |program_exercise|
          new_day.program_exercises.create!(
            exercise: program_exercise.exercise,
            position: program_exercise.position,
            target_sets: program_exercise.target_sets,
            target_reps: program_exercise.target_reps,
            target_duration_minutes: program_exercise.target_duration_minutes
          )
        end
      end

      copy
    end
  end

  private

  attr_reader :source
end
