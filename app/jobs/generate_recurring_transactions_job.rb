class GenerateRecurringTransactionsJob < ApplicationJob
  queue_as :default

  def perform
    RecurringEntryGenerator.call
  end
end
