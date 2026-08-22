FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Conta #{n}" }
    account_type { :checking }
    initial_balance { 1000.0 }
  end
end
