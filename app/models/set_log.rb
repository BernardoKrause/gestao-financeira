class SetLog < ApplicationRecord
  belongs_to :workout_session
  belongs_to :program_exercise

  validates :position, presence: true
  validates :reps, numericality: { greater_than: 0 }, allow_nil: true
  validates :weight_kg, numericality: { greater_than: 0 }, allow_nil: true
  validates :duration_minutes, numericality: { greater_than: 0 }, allow_nil: true
end
