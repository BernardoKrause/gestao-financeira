require "rails_helper"

RSpec.describe "Registrations", type: :request do
  it "shows the registration form" do
    get new_user_registration_path

    expect(response).to have_http_status(:ok)
  end

  it "creates the user, signs in, seeds a setting and default categories, and redirects to root" do
    expect {
      post user_registration_path, params: { user: { email: "novo@example.com", password: "Strong#Pass1", password_confirmation: "Strong#Pass1" } }
    }.to change(User, :count).by(1)

    expect(response).to redirect_to(dashboard_path)

    user = User.last
    expect(user.setting).to be_present
    expect(user.setting.initial_balance).to eq(0)
    expect(user.categories.pluck(:name)).to contain_exactly(
      "Aluguel", "Assinatura", "Cartão de Crédito", "Contas de Casa", "Esporte",
      "Estética", "Lanchonete/Restaurante", "Mercado", "Padaria", "Saúde",
      "Renda Extra", "Salário", "Vendas"
    )

    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it "does not create the user with an invalid password and re-renders the form" do
    expect {
      post user_registration_path, params: { user: { email: "novo@example.com", password: "weakpass", password_confirmation: "weakpass" } }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "renders validation errors fully in Portuguese, with no leftover English attribute name" do
    post user_registration_path, params: { user: { email: "novo@example.com", password: "weakpass", password_confirmation: "weakpass" } }

    expect(response.body).to include("Senha")
    expect(response.body).not_to include("Password")
  end

  it "allows registration even when a user already exists" do
    create(:user)

    expect {
      post user_registration_path, params: { user: { email: "outro@example.com", password: "Strong#Pass1", password_confirmation: "Strong#Pass1" } }
    }.to change(User, :count).by(1)

    expect(response).to redirect_to(dashboard_path)
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
