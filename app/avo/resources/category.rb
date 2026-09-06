class Avo::Resources::Category < Avo::BaseResource
  self.icon = "tabler/outline/folder"

  def fields
    field :id, as: :id
    field :name, as: :text
    field :kind, as: :select, enum: ::Category.kinds
    field :user, as: :belongs_to
    field :transactions, as: :has_many
    field :recurring_entries, as: :has_many
  end
end
