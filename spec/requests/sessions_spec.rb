require "rails_helper"

RSpec.describe "Sessions", type: :request do
  it "always shows a 'Criar conta' link, even when a user already exists" do
    create(:user)

    get new_user_session_path

    expect(response.body).to include("Criar conta")
  end

  it "renders inside the auth layout, not the main app layout" do
    get new_user_session_path

    expect(response.body).to include("← Hub")
  end

  it "does not preload Avo's JS bundle on public pages" do
    get new_user_session_path

    expect(response.body).not_to match(%r{<link rel="modulepreload"[^>]*avo/application})
  end
end
