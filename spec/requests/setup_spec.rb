require "rails_helper"

RSpec.describe "Setup", type: :request do
  describe "when no user exists" do
    it "shows the setup form" do
      get new_setup_path

      expect(response).to have_http_status(:ok)
    end

    it "creates the user, signs in, and redirects to root" do
      expect {
        post setup_path, params: { user: { email: "dono@example.com", password: "Strong#Pass1", password_confirmation: "Strong#Pass1" } }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_path)

      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "does not create the user with an invalid password and re-renders the form" do
      expect {
        post setup_path, params: { user: { email: "dono@example.com", password: "weakpass", password_confirmation: "weakpass" } }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "when a user already exists" do
    before { create(:user) }

    it "redirects GET /setup to sign in without rendering the form" do
      get new_setup_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects POST /setup to sign in without creating another user" do
      expect {
        post setup_path, params: { user: { email: "outro@example.com", password: "Strong#Pass1", password_confirmation: "Strong#Pass1" } }
      }.not_to change(User, :count)

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
