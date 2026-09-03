FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Categoria #{n}" }
    kind { :expense }
    user
  end
end
