class RemoveAccountsCreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.decimal :initial_balance, precision: 12, scale: 2, null: false, default: 0

      t.timestamps
    end

    remove_reference :transactions, :account, foreign_key: true
    remove_reference :recurring_entries, :account, foreign_key: true

    drop_table :accounts do |t|
      t.string :name, null: false
      t.integer :account_type, null: false, default: 0
      t.decimal :initial_balance, precision: 12, scale: 2, null: false, default: 0

      t.timestamps
    end
  end
end
