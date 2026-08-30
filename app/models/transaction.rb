class Transaction < ApplicationRecord
  enum :kind, { expense: 0, income: 1 }

  belongs_to :category
  belongs_to :recurring_entry, optional: true

  validates :description, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :date, presence: true

  def signed_amount
    income? ? amount : -amount
  end

  def future?
    date > Date.current
  end
end
