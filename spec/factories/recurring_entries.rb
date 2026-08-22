FactoryBot.define do
  factory :recurring_entry do
    description { "Aluguel" }
    amount { 1500 }
    kind { :expense }
    day_of_month { 5 }
    active { true }
    start_date { Date.current.beginning_of_month }
    end_date { nil }
    account
    category
  end
end
