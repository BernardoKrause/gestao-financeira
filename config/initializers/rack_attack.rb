class Rack::Attack
  self.cache.store = Rails.cache
  self.enabled = Rails.env.production?

  safelist("allow health check") do |req|
    req.path == "/up"
  end

  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets/")
  end

  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end

  throttle("password_resets/ip", limit: 5, period: 20.minutes) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  throttle("password_resets/email", limit: 5, period: 20.minutes) do |req|
    if req.path == "/users/password" && req.post?
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end
end
