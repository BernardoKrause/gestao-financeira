class RecurringEntryGenerator
  def self.call(today: Date.current, user: nil)
    new(today: today, user: user).call
  end

  def initialize(today:, user: nil)
    @today = today
    @user = user
  end

  def call
    due_entries.each { |entry| generate_transaction_for(entry) }
  end

  private

  attr_reader :today, :user

  def due_entries
    candidates = base_scope
                   .where("day_of_month <= ? OR (? = ? AND day_of_month > ?)",
                          today.day, today.day, today.end_of_month.day, today.end_of_month.day)
                   .where("start_date <= ?", today)

    # end_date is computed (from start_date + installments), not a column,
    # so it can't be filtered in SQL — filter the (small) candidate set in Ruby.
    candidates.select { |entry| entry.end_date.nil? || entry.end_date >= today }
  end

  def base_scope
    user ? user.recurring_entries.active : RecurringEntry.active
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
