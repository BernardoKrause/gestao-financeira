class RecurringEntryGenerator
  def self.call(today: Date.current)
    new(today: today).call
  end

  def initialize(today:)
    @today = today
  end

  def call
    due_entries.find_each { |entry| generate_transaction_for(entry) }
  end

  private

  attr_reader :today

  def due_entries
    RecurringEntry.active
                  .where("day_of_month <= ?", today.day)
                  .where("start_date <= ?", today)
                  .where("end_date IS NULL OR end_date >= ?", today)
  end

  def generate_transaction_for(entry)
    return if entry.transactions.where(date: today.beginning_of_month..today.end_of_month).exists?

    entry.transactions.create!(
      description: entry.description,
      amount: entry.amount,
      kind: entry.kind,
      account: entry.account,
      category: entry.category,
      date: transaction_date_for(entry)
    )
  end

  def transaction_date_for(entry)
    day = [ entry.day_of_month, today.end_of_month.day ].min
    Date.new(today.year, today.month, day)
  end
end
