email = ENV.fetch("SEED_USER_EMAIL")
password = ENV.fetch("SEED_USER_PASSWORD")

user = User.find_or_create_by!(email: email) do |u|
  u.password = password
  u.password_confirmation = password
end

UserOnboarding.call(user) unless user.setting
