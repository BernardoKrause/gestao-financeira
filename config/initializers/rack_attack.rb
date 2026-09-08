class Rack::Attack
  self.cache.store = Rails.cache
  self.enabled = Rails.env.production?

  safelist("allow health check") do |req|
    req.path == "/up"
  end

  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets/")
  end
end
