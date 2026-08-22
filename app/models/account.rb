class Account < ApplicationRecord
  enum :account_type, { checking: 0, savings: 1, credit_card: 2, cash: 3 }

  validates :name, presence: true
  validates :account_type, presence: true
  validates :initial_balance, numericality: true
end
