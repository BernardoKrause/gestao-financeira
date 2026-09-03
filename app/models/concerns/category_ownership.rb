module CategoryOwnership
  extend ActiveSupport::Concern

  included do
    validate :category_belongs_to_user
  end

  private

  def category_belongs_to_user
    return if category.nil? || user.nil? || category.user_id == user_id

    errors.add(:category, "deve pertencer ao mesmo usuário")
  end
end
