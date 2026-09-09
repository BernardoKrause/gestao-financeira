class Rack::Attack
  LOGIN_PATH = %r{\A/users/sign_in(?:\.[a-z0-9]+)?\z}i
  PASSWORD_RESET_PATH = %r{\A/users/password(?:\.[a-z0-9]+)?\z}i

  TOO_MANY_REQUESTS_BODY = Rails.root.join("public/429.html").read.freeze

  self.cache.store = Rails.cache
  self.enabled = Rails.env.production?

  def self.throttled_email(req)
    req.params.dig("user", "email").to_s.scrub.downcase.strip.first(255).presence
  rescue ArgumentError
    nil
  end

  safelist("allow health check") do |req|
    req.path == "/up"
  end

  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if LOGIN_PATH.match?(req.path) && req.post?
  end

  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    throttled_email(req) if LOGIN_PATH.match?(req.path) && req.post?
  end

  throttle("password_resets/ip", limit: 5, period: 20.minutes) do |req|
    req.ip if PASSWORD_RESET_PATH.match?(req.path) && req.post?
  end

  throttle("password_resets/email", limit: 5, period: 20.minutes) do |req|
    throttled_email(req) if PASSWORD_RESET_PATH.match?(req.path) && req.post?
  end

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    retry_after = match_data[:period] - (match_data[:epoch_time] % match_data[:period])

    headers = {
      "content-type" => "text/html; charset=utf-8",
      "retry-after" => retry_after.to_s
    }

    [ 429, headers, [ TOO_MANY_REQUESTS_BODY ] ]
  end
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _instrumenter_id, payload|
  request = payload[:request]
  match_data = request.env["rack.attack.match_data"]

  Rails.logger.warn(
    "[rack-attack] blocked ip=#{request.ip} rule=#{request.env['rack.attack.matched']} discriminator=#{match_data[:discriminator]}"
  )
end
