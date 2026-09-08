require "rails_helper"

RSpec.describe "Rack::Attack", type: :request, rack_attack: true do
  describe "general request throttle" do
    it "allows requests under the limit" do
      300.times { get root_path }

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "blocks the request that exceeds the limit" do
      300.times { get root_path }
      get root_path

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "health check safelist" do
    it "never blocks /up even past the general limit" do
      301.times { get root_path }

      get "/up"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "login throttle by IP" do
    it "allows 5 attempts from the same IP in 20 seconds" do
      5.times do |n|
        post user_session_path, params: { user: { email: "attempt#{n}@example.com", password: "wrong" } }
      end

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "blocks the 6th attempt from the same IP in 20 seconds" do
      6.times do |n|
        post user_session_path, params: { user: { email: "attempt#{n}@example.com", password: "wrong" } }
      end

      expect(response).to have_http_status(:too_many_requests)
    end

    it "blocks the 6th attempt even when a format suffix is appended to the path" do
      6.times do |n|
        post "/users/sign_in.json", params: { user: { email: "attempt#{n}@example.com", password: "wrong" } }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "login throttle by email" do
    it "allows 5 attempts against the same email from different IPs" do
      user = create(:user)

      5.times do |n|
        post user_session_path,
          params: { user: { email: user.email, password: "wrong" } },
          headers: { "REMOTE_ADDR" => "10.0.0.#{n}" }
      end

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "blocks the 6th attempt against the same email even from different IPs" do
      user = create(:user)

      6.times do |n|
        post user_session_path,
          params: { user: { email: user.email, password: "wrong" } },
          headers: { "REMOTE_ADDR" => "10.0.0.#{n}" }
      end

      expect(response).to have_http_status(:too_many_requests)
    end

    it "does not raise or 500 when the email param contains invalid UTF-8" do
      expect do
        post user_session_path, params: { user: { email: "a\xC0\x80b", password: "wrong" } }
      end.not_to raise_error

      expect(response.status).to be < 500
    end
  end

  describe "password reset throttle by IP" do
    it "allows 5 attempts from the same IP in 20 minutes" do
      5.times do |n|
        post user_password_path, params: { user: { email: "attempt#{n}@example.com" } }
      end

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "blocks the 6th attempt from the same IP in 20 minutes" do
      6.times do |n|
        post user_password_path, params: { user: { email: "attempt#{n}@example.com" } }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "password reset throttle by email" do
    it "allows 5 attempts against the same email from different IPs" do
      user = create(:user)

      5.times do |n|
        post user_password_path,
          params: { user: { email: user.email } },
          headers: { "REMOTE_ADDR" => "10.0.1.#{n}" }
      end

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "blocks the 6th attempt against the same email even from different IPs" do
      user = create(:user)

      6.times do |n|
        post user_password_path,
          params: { user: { email: user.email } },
          headers: { "REMOTE_ADDR" => "10.0.1.#{n}" }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "throttled response" do
    it "returns a Portuguese 429 page with a Retry-After header" do
      301.times { get root_path }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"].to_i).to be_between(1, 300)
      expect(response.body).to include("Muitas requisições")
    end

    it "logs a warning with the IP and the matched rule" do
      allow(Rails.logger).to receive(:warn).and_call_original

      301.times { get root_path }

      expect(Rails.logger).to have_received(:warn).with(/rack-attack.*ip=.*rule=/i).at_least(:once)
    end
  end
end
