FactoryBot.define do
  factory :exercise do
    sequence(:name) { |n| "Exercício #{n}" }
    muscle_group { :chest }
    kind { :strength }
    user { nil }

    trait :custom do
      user { create(:user) }
    end

    trait :cardio do
      kind { :cardio }
    end

    trait :stretching do
      kind { :stretching }
    end
  end
end
