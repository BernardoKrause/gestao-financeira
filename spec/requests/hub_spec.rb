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

  it "does not show the Gestão Financeira nav bar, even when signed in" do
    user = create(:user)
    sign_in user

    get root_path

    expect(response.body).not_to include("Painel")
  end

  it "shows a card linking to the Gestão Financeira dashboard" do
    get root_path

    expect(response.body).to include("Gestão Financeira")
    expect(response.body).to include(%(href="#{dashboard_path}"))
  end

  it "shows an Entrar link when signed out and a Sair button when signed in" do
    get root_path
    expect(response.body).to include("Entrar")

    user = create(:user)
    sign_in user
    get root_path
    expect(response.body).to include("Sair")
  end
end
