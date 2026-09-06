class Avo::Resources::User < Avo::BaseResource
  self.icon = "tabler/outline/users"
  self.title = :email
  self.devise_password_optional = true

  def fields
    field :id, as: :id
    field :email, as: :text
    field :password, as: :password
    field :password_confirmation, as: :password
    field :transactions, as: :has_many
    field :recurring_entries, as: :has_many
    field :categories, as: :has_many
    field :setting, as: :has_one
  end
end
