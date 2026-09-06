class Avo::Resources::Setting < Avo::BaseResource
  self.icon = "heroicons/outline/cog"

  def fields
    field :id, as: :id
    field :initial_balance, as: :number
    field :user, as: :belongs_to
  end
end
