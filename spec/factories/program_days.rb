FactoryBot.define do
  factory :program_day do
    label { "A" }
    title { "Peito e Tríceps" }
    position { 0 }
    workout_program
  end
end
