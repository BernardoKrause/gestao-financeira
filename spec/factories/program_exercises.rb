FactoryBot.define do
  factory :program_exercise do
    position { 0 }
    target_sets { 4 }
    target_reps { 10 }
    target_duration_minutes { nil }
    program_day
    exercise

    trait :cardio do
      exercise { association :exercise, :cardio }
      target_sets { nil }
      target_reps { nil }
      target_duration_minutes { 30 }
    end
  end
end
