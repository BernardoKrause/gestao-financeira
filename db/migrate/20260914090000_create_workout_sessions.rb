class CreateWorkoutSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :workout_program, null: false, foreign_key: true
      t.references :program_day, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :finished_at

      t.timestamps
    end
  end
end
