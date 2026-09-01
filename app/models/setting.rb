class Setting < ApplicationRecord
  CONFIDENCE_LEVELS = %i[confirmed recurring all].freeze

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

  def projected_balance_for(confidence:, as_of: Date.current)
    case confidence.to_sym
    when :confirmed
      current_balance(as_of: as_of)
    when :recurring
      projected_month_end_balance(as_of: as_of)
    when :all
      projected_month_end_balance(as_of: as_of) +
        pending_one_off_income_total(as_of: as_of) -
        pending_one_off_expense_total(as_of: as_of)
    else
      raise ArgumentError, "unknown confidence level: #{confidence.inspect}"
    end
  end

  def financial_health_status(as_of: Date.current)
    financial_health_status_for(confidence: :recurring, as_of: as_of)
  end

  def financial_health_status_for(confidence:, as_of: Date.current)
    projected = projected_balance_for(confidence: confidence, as_of: as_of)
    return :critical if projected.negative?
    return :warning if monthly_recurring_expense_total(as_of: as_of) > monthly_recurring_income_total(as_of: as_of)

    :healthy
  end

  def pending_recurring_income_total(as_of: Date.current)
    pending_recurring_entries(as_of: as_of).select(&:income?).sum(&:amount)
  end

  def pending_recurring_expense_total(as_of: Date.current)
    pending_recurring_entries(as_of: as_of).select(&:expense?).sum(&:amount)
  end

  def pending_one_off_income_total(as_of: Date.current)
    pending_one_off_transactions(as_of: as_of).select(&:income?).sum(&:amount)
  end

  def pending_one_off_expense_total(as_of: Date.current)
    pending_one_off_transactions(as_of: as_of).select(&:expense?).sum(&:amount)
  end

  def cash_flow_series(month: Date.current, as_of: Date.current, confidence: :recurring)
    days = (month.beginning_of_month..month.end_of_month).to_a

    {
      labels: days.map(&:day),
      historical: days.map { |day| day <= as_of ? current_balance(as_of: day) : nil },
      projected: days.map { |day| day < as_of ? nil : projected_balance_on(day, as_of: as_of, confidence: confidence) }
    }
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
  # left to happen". financial_health_status_for uses this (not
  # pending_recurring_*) for every confidence level, so :warning doesn't
  # collapse to :healthy the moment every recurring entry for the month has
  # already fired, and doesn't vary with which balance view is selected.
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

  def pending_one_off_transactions(as_of:)
    Transaction.where(date: (as_of + 1)..as_of.end_of_month, recurring_entry_id: nil)
  end

  def projected_balance_on(day, as_of:, confidence:)
    return current_balance(as_of: as_of) if day == as_of

    case confidence.to_sym
    when :confirmed
      current_balance(as_of: as_of)
    when :recurring
      current_balance(as_of: as_of) + recurring_net_between(as_of + 1, day)
    when :all
      current_balance(as_of: as_of) + recurring_net_between(as_of + 1, day) + one_off_net_between(as_of + 1, day)
    else
      raise ArgumentError, "unknown confidence level: #{confidence.inspect}"
    end
  end

  def recurring_net_between(from, to)
    RecurringEntry.active.sum do |entry|
      (from..to).sum { |date| fires_on?(entry, date) ? entry_signed_amount(entry) : 0 }
    end
  end

  def one_off_net_between(from, to)
    Transaction.where(date: from..to, recurring_entry_id: nil).sum(&:signed_amount)
  end

  def fires_on?(entry, date)
    return false unless entry.start_date <= date && (entry.end_date.nil? || entry.end_date >= date)

    date.day == [ entry.day_of_month, date.end_of_month.day ].min
  end

  def entry_signed_amount(entry)
    entry.income? ? entry.amount : -entry.amount
  end
end
