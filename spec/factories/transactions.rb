FactoryBot.define do
  factory :transaction do
    description { "Compra no mercado" }
    amount { 150.50 }
    kind { :expense }
    date { Date.current }
    user
    category { association :category, user: instance.user }
  end
end
