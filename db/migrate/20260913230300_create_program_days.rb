class CreateProgramDays < ActiveRecord::Migration[8.1]
  def change
    create_table :program_days do |t|
      t.references :workout_program, null: false, foreign_key: true
      t.string :label, null: false
      t.string :title, null: false
      t.integer :position, null: false

      t.timestamps
    end
  end
end
