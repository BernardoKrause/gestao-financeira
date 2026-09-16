class SetLog < ApplicationRecord
  belongs_to :workout_session
  belongs_to :program_exercise

  scope :completed_with_weight, -> { where(completed: true).where.not(weight_kg: nil) }

  validates :position, presence: true
  validates :reps, numericality: { greater_than: 0 }, allow_nil: true
  validates :weight_kg, numericality: { greater_than: 0 }, allow_nil: true
  validates :duration_minutes, numericality: { greater_than: 0 }, allow_nil: true

  def self.strength_progress_summary(user)
    exercise_id_by_program_exercise_id = ProgramExercise.joins(:exercise, program_day: :workout_program)
      .where(exercises: { kind: Exercise.kinds["strength"] }, workout_programs: { user_id: user.id })
      .pluck(:id, :exercise_id)
      .to_h

    rows = completed_with_weight
      .joins(:workout_session)
      .where(program_exercise_id: exercise_id_by_program_exercise_id.keys)
      .where(workout_sessions: { user_id: user.id, status: WorkoutSession.statuses["completed"] })
      .pluck(:program_exercise_id, Arel.sql("workout_sessions.finished_at"))

    rows.group_by { |program_exercise_id, _| exercise_id_by_program_exercise_id[program_exercise_id] }
        .transform_values { |group| group.map(&:last).max }
  end

  def self.max_weight_by_day(user:, exercise_id:, since: nil)
    scope = completed_with_weight
      .joins(:workout_session)
      .where(program_exercise_id: ProgramExercise.where(exercise_id: exercise_id))
      .where(workout_sessions: { user_id: user.id, status: WorkoutSession.statuses["completed"] })
    scope = scope.where(workout_sessions: { finished_at: since.. }) if since

    pairs = scope.pluck(:weight_kg, Arel.sql("workout_sessions.finished_at"))
    pairs.group_by { |_, finished_at| finished_at.to_date }
         .transform_values { |rows| rows.map(&:first).max }
  end

  def self.personal_records_for(workout_session)
    exercise_id_by_program_exercise_id = ProgramExercise.joins(:exercise)
      .where(id: workout_session.set_logs.select(:program_exercise_id), exercises: { kind: Exercise.kinds["strength"] })
      .pluck(:id, :exercise_id)
      .to_h
    return {} if exercise_id_by_program_exercise_id.empty?

    current_max_by_program_exercise_id = completed_with_weight
      .where(workout_session: workout_session, program_exercise_id: exercise_id_by_program_exercise_id.keys)
      .pluck(:program_exercise_id, :weight_kg)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).max }

    records = {}
    exercise_id_by_program_exercise_id.each do |program_exercise_id, exercise_id|
      current_max = current_max_by_program_exercise_id[program_exercise_id]
      next if current_max.nil?

      previous_max = completed_with_weight
        .joins(:workout_session)
        .where(program_exercise_id: ProgramExercise.where(exercise_id: exercise_id))
        .where(workout_sessions: { user_id: workout_session.user_id, status: WorkoutSession.statuses["completed"] })
        .where("workout_sessions.finished_at < ?", workout_session.finished_at)
        .maximum(:weight_kg)

      records[program_exercise_id] = current_max if previous_max.present? && current_max > previous_max
    end

    records
  end
end
