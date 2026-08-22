require "rails_helper"

RSpec.describe GenerateRecurringTransactionsJob, type: :job do
  it "delegates to RecurringEntryGenerator" do
    expect(RecurringEntryGenerator).to receive(:call)

    described_class.perform_now
  end
end
