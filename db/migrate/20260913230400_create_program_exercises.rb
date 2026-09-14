class CreateProgramExercises < ActiveRecord::Migration[8.1]
  def change
    create_table :program_exercises do |t|
      t.references :program_day, null: false, foreign_key: true
      t.references :exercise, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :target_sets
      t.integer :target_reps
      t.integer :target_duration_minutes

      t.timestamps
    end
  end
end
