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

  it "matches the admin email case-insensitively" do
    allow(Rails.application.credentials).to receive(:admin_email).and_return("Admin@Example.com")

    sign_in admin
    get "/admin"
    follow_redirect!

    expect(response).to have_http_status(:ok)
  end

  it "404s a non-admin user on /admin/overview, not just /admin" do
    sign_in other_user
    get "/admin/overview"
    expect(response).to have_http_status(:not_found)
  end

  it "404s a non-admin user on an admin resource page" do
    sign_in other_user
    get "/admin/resources/users"
    expect(response).to have_http_status(:not_found)
  end

  context "when admin_email is not configured" do
    before do
      allow(Rails.application.credentials).to receive(:admin_email).and_return(nil)
    end

    it "404s everyone, including the intended admin" do
      sign_in admin
      get "/admin"
      expect(response).to have_http_status(:not_found)
    end

    it "404s a regular user too" do
      sign_in other_user
      get "/admin"
      expect(response).to have_http_status(:not_found)
    end
  end
end
