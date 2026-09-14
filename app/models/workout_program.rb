class WorkoutProgram < ApplicationRecord
  belongs_to :user
  has_many :program_days, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true

  def activate!
    transaction do
      user.workout_programs.update_all(active: false)
      update!(active: true)
    end
  end
end
