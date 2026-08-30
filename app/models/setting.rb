class Setting < ApplicationRecord
  validates :initial_balance, numericality: true

  def self.instance
    first_or_create!(initial_balance: 0)
  end

  def current_balance(as_of: Date.current)
    initial_balance + Transaction.where(date: ..as_of).sum(&:signed_amount)
  end

  def projected_month_end_balance(as_of: Date.current)
    current_balance(as_of: as_of) +
      pending_recurring_income_total(as_of: as_of) -
      pending_recurring_expense_total(as_of: as_of)
  end

  def pending_recurring_income_total(as_of: Date.current)
    pending_recurring_entries(as_of: as_of).select(&:income?).sum(&:amount)
  end

  def pending_recurring_expense_total(as_of: Date.current)
    pending_recurring_entries(as_of: as_of).select(&:expense?).sum(&:amount)
  end

  def financial_health_status(as_of: Date.current)
    projected = projected_month_end_balance(as_of: as_of)
    return :critical if projected.negative?
    return :warning if monthly_recurring_expense_total(as_of: as_of) > monthly_recurring_income_total(as_of: as_of)

    :healthy
  end

  private

  def pending_recurring_entries(as_of:)
    return [] if as_of.day == as_of.end_of_month.day

    RecurringEntry.active.select { |entry| pending?(entry, as_of) }
  end

  def pending?(entry, as_of)
    entry.day_of_month > as_of.day && fires_within_month?(entry, as_of)
  end

  # Counts an entry whether or not its day_of_month has already passed this
  # month — answers "is this a structurally deficit month", not "what's
  # left to happen". financial_health_status uses this (not
  # pending_recurring_*) so the :warning badge doesn't collapse to :healthy
  # the moment every recurring entry for the month has already fired.
  def monthly_recurring_income_total(as_of:)
    monthly_recurring_entries(as_of: as_of).select(&:income?).sum(&:amount)
  end

  def monthly_recurring_expense_total(as_of:)
    monthly_recurring_entries(as_of: as_of).select(&:expense?).sum(&:amount)
  end

  def monthly_recurring_entries(as_of:)
    RecurringEntry.active.select { |entry| fires_within_month?(entry, as_of) }
  end

  def fires_within_month?(entry, as_of)
    fire_date = Date.new(as_of.year, as_of.month, [ entry.day_of_month, as_of.end_of_month.day ].min)
    entry.start_date <= fire_date && (entry.end_date.nil? || entry.end_date >= fire_date)
  end
end
