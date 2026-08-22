class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.integer :kind, null: false, default: 0
      t.string :color

      t.timestamps
    end
  end
end
