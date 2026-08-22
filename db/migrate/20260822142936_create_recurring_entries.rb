class CreateRecurringEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :recurring_entries do |t|
      t.references :account, null: false, foreign_key: true
      t.timestamps
    end
  end
end
