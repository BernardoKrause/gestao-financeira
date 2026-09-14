FactoryBot.define do
  factory :workout_session do
    status { :in_progress }
    started_at { Time.current }
    workout_program
    program_day { association :program_day, workout_program: workout_program }
    user { workout_program.user }

    trait :completed do
      status { :completed }
      finished_at { Time.current }
    end
  end
end
