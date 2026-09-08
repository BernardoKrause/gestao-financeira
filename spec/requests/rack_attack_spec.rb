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
end
