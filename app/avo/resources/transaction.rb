class Avo::Resources::Transaction < Avo::BaseResource
  self.icon = "tabler/outline/credit-card-pay"

  def fields
    field :id, as: :id
    field :description, as: :text
    field :amount, as: :number
    field :kind, as: :select, enum: ::Transaction.kinds
    field :date, as: :date
    field :user, as: :belongs_to
    field :category, as: :belongs_to
    field :recurring_entry, as: :belongs_to
  end
end
