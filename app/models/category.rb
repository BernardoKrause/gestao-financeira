class Category < ApplicationRecord
  enum :kind, { expense: 0, income: 1 }

  belongs_to :user
  has_many :transactions, dependent: :restrict_with_error
  has_many :recurring_entries, dependent: :restrict_with_error

  validates :name, presence: true
  validates :kind, presence: true
end
