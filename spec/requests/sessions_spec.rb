require "rails_helper"

RSpec.describe "Sessions", type: :request do
  it "always shows a 'Criar conta' link, even when a user already exists" do
    create(:user)

    get new_user_session_path

    expect(response.body).to include("Criar conta")
  end
end
