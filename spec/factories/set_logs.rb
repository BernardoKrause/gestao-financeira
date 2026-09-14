FactoryBot.define do
  factory :set_log do
    position { 0 }
    reps { 10 }
    weight_kg { 50 }
    workout_session
    program_exercise

    trait :cardio do
      reps { nil }
      weight_kg { nil }
      duration_minutes { 20 }
      program_exercise { association :program_exercise, :cardio }
    end

    trait :completed do
      completed { true }
    end
  end
end
