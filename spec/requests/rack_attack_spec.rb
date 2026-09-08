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
      user = create(:user)

      5.times do
        post user_session_path, params: { user: { email: user.email, password: "wrong" } }
      end

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "blocks the 6th attempt from the same IP in 20 seconds" do
      user = create(:user)

      6.times do
        post user_session_path, params: { user: { email: user.email, password: "wrong" } }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "login throttle by email" do
    it "blocks the 6th attempt against the same email even from different IPs" do
      user = create(:user)

      6.times do |n|
        post user_session_path,
          params: { user: { email: user.email, password: "wrong" } },
          headers: { "REMOTE_ADDR" => "10.0.0.#{n}" }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
