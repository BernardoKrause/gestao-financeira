class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :registerable, :validatable

  has_many :transactions, dependent: :destroy
  has_many :recurring_entries, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_one :setting, dependent: :destroy

  validate :password_complexity

  private

  def password_complexity
    return if password.blank?

    unless password.match?(/\A(?=.*[A-Z])(?=.*[^A-Za-z0-9]).+\z/)
      errors.add(:password, "deve conter ao menos uma letra maiúscula e um caractere especial")
    end
  end
end
