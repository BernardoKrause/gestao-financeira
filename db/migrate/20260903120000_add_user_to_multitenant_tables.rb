class AddUserToMultitenantTables < ActiveRecord::Migration[8.1]
  def up
    add_reference :categories, :user, foreign_key: true
    add_reference :transactions, :user, foreign_key: true
    add_reference :recurring_entries, :user, foreign_key: true
    add_reference :settings, :user, foreign_key: true, index: { unique: true }

    # Single-user app until now: everything existing belongs to the one
    # account that's already there, if any (fresh installs and the test DB
    # have none of these rows yet, so there's nothing to backfill).
    if (user = User.first)
      Category.update_all(user_id: user.id)
      Transaction.update_all(user_id: user.id)
      RecurringEntry.update_all(user_id: user.id)
      Setting.update_all(user_id: user.id)
    end

    change_column_null :categories, :user_id, false
    change_column_null :transactions, :user_id, false
    change_column_null :recurring_entries, :user_id, false
    change_column_null :settings, :user_id, false
  end

  def down
    remove_reference :categories, :user, foreign_key: true
    remove_reference :transactions, :user, foreign_key: true
    remove_reference :recurring_entries, :user, foreign_key: true
    remove_reference :settings, :user, foreign_key: true
  end
end
