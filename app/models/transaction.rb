class Transaction < ApplicationRecord
  enum :kind, { expense: 0, income: 1 }

  belongs_to :account
  belongs_to :category

  validates :description, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :date, presence: true

  def signed_amount
    income? ? amount : -amount
  end
end
