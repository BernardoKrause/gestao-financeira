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

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    retry_after = match_data[:period] - (match_data[:epoch_time] % match_data[:period])

    headers = {
      "Content-Type" => "text/html",
      "Retry-After" => retry_after.to_s
    }

    [ 429, headers, [ File.read(Rails.root.join("public/429.html")) ] ]
  end
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _instrumenter_id, payload|
  request = payload[:request]
  match_data = request.env["rack.attack.match_data"]

  Rails.logger.warn(
    "[rack-attack] blocked ip=#{request.ip} rule=#{request.env['rack.attack.matched']} discriminator=#{match_data[:discriminator]}"
  )
end
