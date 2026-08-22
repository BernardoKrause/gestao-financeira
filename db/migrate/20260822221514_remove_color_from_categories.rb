class RemoveColorFromCategories < ActiveRecord::Migration[8.1]
  def change
    remove_column :categories, :color, :string
  end
end
