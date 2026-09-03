class RecurringEntryGenerator
  def self.call(today: Date.current)
    new(today: today).call
  end

  def initialize(today:)
    @today = today
  end

  def call
    due_entries.each { |entry| generate_transaction_for(entry) }
  end

  private

  attr_reader :today

  def due_entries
    candidates = RecurringEntry.active
                                .where("day_of_month <= ? OR (? = ? AND day_of_month > ?)",
                                       today.day, today.day, today.end_of_month.day, today.end_of_month.day)
                                .where("start_date <= ?", today)

    # end_date is computed (from start_date + installments), not a column,
    # so it can't be filtered in SQL — filter the (small) candidate set in Ruby.
    candidates.select { |entry| entry.end_date.nil? || entry.end_date >= today }
  end

  def generate_transaction_for(entry)
    return if entry.transactions.where(date: today.beginning_of_month..today.end_of_month).exists?

    entry.transactions.create!(
      description: entry.description,
      amount: entry.amount,
      kind: entry.kind,
      category: entry.category,
      user: entry.user,
      date: transaction_date_for(entry)
    )
  end

  def transaction_date_for(entry)
    day = [ entry.day_of_month, today.end_of_month.day ].min
    Date.new(today.year, today.month, day)
  end
end
