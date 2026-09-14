class CreateExercises < ActiveRecord::Migration[8.1]
  def change
    create_table :exercises do |t|
      t.references :user, null: true, foreign_key: true
      t.string :name, null: false
      t.integer :muscle_group, null: false
      t.integer :kind, null: false, default: 0
      t.text :notes

      t.timestamps
    end
  end
end
