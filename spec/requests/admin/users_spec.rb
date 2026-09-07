require "rails_helper"

RSpec.describe "Admin users", type: :request do
  let(:admin) { create(:user, email: "admin@example.com") }

  before do
    allow(Rails.application.credentials).to receive(:admin_email).and_return("admin@example.com")
    sign_in admin
  end

  it "creates a user with a password" do
    expect {
      post "/admin/resources/users", params: {
        user: { email: "novo@example.com", password: "Strong#Pass1", password_confirmation: "Strong#Pass1" }
      }
    }.to change(User, :count).by(1)

    created = User.find_by(email: "novo@example.com")
    expect(created).to be_present
    expect(created.setting).to be_present
    expect(created.categories.count).to eq(13)
  end

  it "updates a user without touching their password" do
    target = create(:user, email: "alvo@example.com")
    original_digest = target.encrypted_password

    put "/admin/resources/users/#{target.id}", params: { user: { email: "alvo-novo@example.com" } }

    target.reload
    expect(target.email).to eq("alvo-novo@example.com")
    expect(target.encrypted_password).to eq(original_digest)
  end
end
