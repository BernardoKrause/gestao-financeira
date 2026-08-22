class CreateRecurringEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_entries do |t|
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :kind, null: false, default: 0
      t.references :account, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.integer :day_of_month, null: false
      t.boolean :active, null: false, default: true
      t.date :start_date, null: false
      t.date :end_date

      t.timestamps
    end
  end
end
