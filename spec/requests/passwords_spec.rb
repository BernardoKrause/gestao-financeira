require "rails_helper"

RSpec.describe "Passwords", type: :request do
  it "shows the forgot-password form" do
    get new_user_password_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Esqueceu sua senha?")
  end

  it "sends reset instructions for a known email" do
    user = create(:user)

    expect {
      post user_password_path, params: { user: { email: user.email } }
    }.to change { ActionMailer::Base.deliveries.count }.by(1)

    expect(response).to redirect_to(new_user_session_path)
  end

  it "resets the password with a valid token and signs the user in" do
    user = create(:user)
    token = user.send_reset_password_instructions

    put user_password_path, params: {
      user: {
        reset_password_token: token,
        password: "NewStrong#Pass1",
        password_confirmation: "NewStrong#Pass1"
      }
    }

    expect(response).to redirect_to(dashboard_path)
    expect(user.reload.valid_password?("NewStrong#Pass1")).to be(true)
  end
end
