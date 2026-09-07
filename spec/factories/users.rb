FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Strong#Pass1" }
    password_confirmation { "Strong#Pass1" }
    skip_onboarding { true }
  end
end
