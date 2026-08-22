email = ENV.fetch("SEED_USER_EMAIL")
password = ENV.fetch("SEED_USER_PASSWORD")

User.find_or_create_by!(email: email) do |user|
  user.password = password
  user.password_confirmation = password
end
