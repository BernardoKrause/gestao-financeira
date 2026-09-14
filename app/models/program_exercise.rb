class ProgramExercise < ApplicationRecord
  belongs_to :program_day
  belongs_to :exercise

  validates :position, presence: true
  validates :target_sets, presence: true, numericality: { greater_than: 0 }, if: -> { exercise&.strength? }
  validates :target_reps, presence: true, numericality: { greater_than: 0 }, if: -> { exercise&.strength? }
  validates :target_duration_minutes, presence: true, numericality: { greater_than: 0 }, if: -> { exercise&.cardio? }
end
