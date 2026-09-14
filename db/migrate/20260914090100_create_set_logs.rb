class CreateSetLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :set_logs do |t|
      t.references :workout_session, null: false, foreign_key: true
      t.references :program_exercise, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :reps
      t.decimal :weight_kg, precision: 6, scale: 2
      t.integer :duration_minutes
      t.boolean :completed, null: false, default: false

      t.timestamps
    end
  end
end
