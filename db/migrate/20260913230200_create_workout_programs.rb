class CreateWorkoutPrograms < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_programs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: false

      t.timestamps
    end
  end
end
