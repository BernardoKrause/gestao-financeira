require "rails_helper"

RSpec.describe "Hub", type: :request do
  it "is publicly accessible without authentication" do
    get root_path

    expect(response).to have_http_status(:ok)
  end

  it "sends an unauthenticated visitor to the financas dashboard after logging in from a protected page" do
    user = create(:user)

    get dashboard_path
    expect(response).to redirect_to(new_user_session_path)

    post user_session_path, params: { user: { email: user.email, password: "Strong#Pass1" } }

    expect(response).to redirect_to(dashboard_path)
  end
end
