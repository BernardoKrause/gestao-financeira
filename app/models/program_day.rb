class ProgramDay < ApplicationRecord
  belongs_to :workout_program
  has_many :program_exercises, -> { order(:position) }, dependent: :destroy

  validates :label, presence: true
  validates :title, presence: true
  validates :position, presence: true
end
