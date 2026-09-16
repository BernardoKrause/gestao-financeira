if Rails.env.development?
  test_user = User.find_or_create_by!(email: "teste@teste.com") do |u|
    u.password = "Teste@123"
    u.password_confirmation = "Teste@123"
  end

  UserOnboarding.call(test_user) unless test_user.setting
end

if ENV["SEED_USER_EMAIL"].present?
  email = ENV.fetch("SEED_USER_EMAIL")
  password = ENV.fetch("SEED_USER_PASSWORD")

  user = User.find_or_create_by!(email: email) do |u|
    u.password = password
    u.password_confirmation = password
  end

  UserOnboarding.call(user) unless user.setting
end

ExerciseCatalogSeeder.call
