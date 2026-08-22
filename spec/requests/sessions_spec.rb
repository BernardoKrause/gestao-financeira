require "rails_helper"

RSpec.describe "Sessions", type: :request do
  it "shows a 'Criar conta' link when no user exists yet" do
    get new_user_session_path

    expect(response.body).to include("Criar conta")
  end

  it "hides the 'Criar conta' link once a user exists" do
    create(:user)

    get new_user_session_path

    expect(response.body).not_to include("Criar conta")
  end
end
