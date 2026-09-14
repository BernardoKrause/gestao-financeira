class WorkoutSession < ApplicationRecord
  belongs_to :user
  belongs_to :workout_program
  belongs_to :program_day
  has_many :set_logs, dependent: :destroy

  enum :status, { in_progress: 0, completed: 1 }

  validates :started_at, presence: true
end
