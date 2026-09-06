class Avo::Resources::RecurringEntry < Avo::BaseResource
  def fields
    field :id, as: :id
    field :description, as: :text
    field :amount, as: :number
    field :kind, as: :select, enum: ::RecurringEntry.kinds
    field :day_of_month, as: :number
    field :active, as: :boolean
    field :start_date, as: :date
    field :installments, as: :number
    field :user, as: :belongs_to
    field :category, as: :belongs_to
    field :transactions, as: :has_many
  end
end
