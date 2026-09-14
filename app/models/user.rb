class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :registerable, :validatable

  attr_accessor :skip_onboarding

  has_many :transactions, dependent: :destroy
  has_many :recurring_entries, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :workout_programs, dependent: :destroy
  has_many :workout_sessions, dependent: :destroy
  has_many :exercises, dependent: :destroy
  has_one :setting, dependent: :destroy

  validate :password_complexity
  after_create :onboard_new_user, unless: :skip_onboarding

  private

  def password_complexity
    return if password.blank?

    unless password.match?(/\A(?=.*[A-Z])(?=.*[^A-Za-z0-9]).+\z/)
      errors.add(:password, "deve conter ao menos uma letra maiúscula e um caractere especial")
    end
  end

  def onboard_new_user
    UserOnboarding.call(self)
  end
end
