require "rails_helper"

RSpec.describe "Sessions", type: :request do
  it "does not show a 'Criar conta' link (signup is disabled)" do
    create(:user)

    get new_user_session_path

    expect(response.body).not_to include("Criar conta")
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
