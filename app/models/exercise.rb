class Exercise < ApplicationRecord
  belongs_to :user, optional: true
  has_many :program_exercises, dependent: :restrict_with_error

  enum :muscle_group, { chest: 0, triceps: 1, back: 2, biceps: 3, legs: 4, glutes: 5, shoulders: 6, abs: 7 }
  enum :kind, { strength: 0, cardio: 1 }

  MUSCLE_GROUP_LABELS = {
    "chest" => "Peito", "triceps" => "Tríceps", "back" => "Costas", "biceps" => "Bíceps",
    "legs" => "Pernas", "glutes" => "Glúteos", "shoulders" => "Ombros", "abs" => "Abdômen"
  }.freeze

  KIND_LABELS = { "strength" => "Força", "cardio" => "Cardio" }.freeze

  validates :name, presence: true
  validates :muscle_group, presence: true
  validates :kind, presence: true

  scope :visible_to, ->(user) { where(user: nil).or(where(user: user)) }

  def global?
    user_id.nil?
  end
end
