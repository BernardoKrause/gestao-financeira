require "rails_helper"

RSpec.describe "Admin access", type: :request do
  let(:admin) { create(:user, email: "admin@example.com") }
  let(:other_user) { create(:user) }

  before do
    allow(Rails.application.credentials).to receive(:admin_email).and_return("admin@example.com")
  end

  it "redirects an anonymous visitor to sign in" do
    expected_path = new_user_session_path
    get "/admin"
    expect(response).to redirect_to(expected_path)
  end

  it "404s for a signed-in user who is not the admin" do
    sign_in other_user
    get "/admin"
    expect(response).to have_http_status(:not_found)
  end

  it "lets the admin user in" do
    sign_in admin
    get "/admin"
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end
end
