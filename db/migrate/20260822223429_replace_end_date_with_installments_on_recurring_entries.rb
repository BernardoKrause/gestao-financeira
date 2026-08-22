class ReplaceEndDateWithInstallmentsOnRecurringEntries < ActiveRecord::Migration[8.1]
  def change
    remove_column :recurring_entries, :end_date, :date
    add_column :recurring_entries, :installments, :integer
  end
end
