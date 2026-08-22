require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "updates the initial balance and redirects to the dashboard" do
    patch setting_path, params: { setting: { initial_balance: 2500 } }

    expect(response).to redirect_to(root_path)
    expect(Setting.instance.initial_balance).to eq(2500)
  end

  it "does not update with an invalid value and re-renders the dashboard" do
    Setting.instance.update!(initial_balance: 1000)

    patch setting_path, params: { setting: { initial_balance: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(Setting.instance.initial_balance).to eq(1000)
  end
end
