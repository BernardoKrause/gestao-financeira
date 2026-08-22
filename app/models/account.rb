class Account < ApplicationRecord
  enum :account_type, { checking: 0, savings: 1, credit_card: 2, cash: 3 }

  has_many :transactions, dependent: :restrict_with_error
  has_many :recurring_entries, dependent: :restrict_with_error

  validates :name, presence: true
  validates :account_type, presence: true
  validates :initial_balance, numericality: true

  def current_balance(as_of: Date.current)
    initial_balance + transactions.where(date: ..as_of).sum(&:signed_amount)
  end

  def projected_month_end_balance(as_of: Date.current)
    current_balance(as_of: as_of) + pending_recurring_signed_total(as_of: as_of)
  end

  private

  def pending_recurring_signed_total(as_of:)
    return 0 if as_of.day == as_of.end_of_month.day

    recurring_entries.active.select { |entry| pending?(entry, as_of) }
                      .sum { |entry| entry.income? ? entry.amount : -entry.amount }
  end

  def pending?(entry, as_of)
    return false unless entry.day_of_month > as_of.day

    fire_date = Date.new(as_of.year, as_of.month, [ entry.day_of_month, as_of.end_of_month.day ].min)
    entry.start_date <= fire_date && (entry.end_date.nil? || entry.end_date >= fire_date)
  end
end
