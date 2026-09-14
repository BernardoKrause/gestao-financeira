FactoryBot.define do
  factory :workout_program do
    sequence(:name) { |n| "Ficha #{n}" }
    active { false }
    user
  end
end
