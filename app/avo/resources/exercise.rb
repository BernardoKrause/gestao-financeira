class Avo::Resources::Exercise < Avo::BaseResource
  self.icon = "tabler/outline/barbell"

  def fields
    field :id, as: :id
    field :name, as: :text
    field :muscle_group, as: :select, enum: ::Exercise.muscle_groups
    field :kind, as: :select, enum: ::Exercise.kinds
    field :notes, as: :textarea
    field :user, as: :belongs_to, help: "Deixe em branco para um exercício do catálogo global."
  end
end
