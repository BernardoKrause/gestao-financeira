class Category < ApplicationRecord
  enum :kind, { expense: 0, income: 1 }

  validates :name, presence: true
  validates :kind, presence: true
end
