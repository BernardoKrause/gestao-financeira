class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :validatable

  validate :password_complexity

  private

  def password_complexity
    return if password.blank?

    unless password.match?(/\A(?=.*[A-Z])(?=.*[^A-Za-z0-9]).+\z/)
      errors.add(:password, "deve conter ao menos uma letra maiúscula e um caractere especial")
    end
  end
end
