class ProgramDay < ApplicationRecord
  belongs_to :workout_program
  has_many :program_exercises, -> { order(:position) }, dependent: :destroy
  has_many :workout_sessions, dependent: :destroy

  validates :label, presence: true
  validates :title, presence: true
  validates :position, presence: true
end
