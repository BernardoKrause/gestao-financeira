class WorkoutSession < ApplicationRecord
  belongs_to :user
  belongs_to :workout_program
  belongs_to :program_day
  has_many :set_logs, dependent: :destroy

  enum :status, { in_progress: 0, completed: 1 }

  validates :started_at, presence: true

  def self.completed_dates_for(user:, month:)
    where(user: user, status: statuses["completed"], finished_at: month.beginning_of_month.beginning_of_day..month.end_of_month.end_of_day)
      .pluck(:finished_at)
      .map(&:to_date)
      .uniq
  end
end
