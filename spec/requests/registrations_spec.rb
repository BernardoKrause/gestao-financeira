require "rails_helper"

RSpec.describe "Registrations", type: :request do
  it "redirects the registration form to the login page" do
    get new_user_registration_path

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to eq("Cadastro desabilitado. Contate o administrador.")
  end

  it "does not create a user and redirects to the login page" do
    expect {
      post user_registration_path, params: { user: { email: "novo@example.com", password: "Strong#Pass1", password_confirmation: "Strong#Pass1" } }
    }.not_to change(User, :count)

    expect(response).to redirect_to(new_user_session_path)
  end

  it "rejects an account update with the wrong current password, in Portuguese" do
    user = create(:user)
    sign_in user

    put user_registration_path, params: {
      user: {
        email: "novo-email@example.com",
        current_password: "WrongPassword#1"
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Senha atual")
    expect(response.body).not_to include("Current password")
  end
end
