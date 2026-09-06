require "rails_helper"

RSpec.describe "Admin categories", type: :request do
  let(:admin) { create(:user, email: "admin@example.com") }

  before do
    allow(Rails.application.credentials).to receive(:admin_email).and_return("admin@example.com")
    sign_in admin
  end

  it "lists categories" do
    category = create(:category, user: admin)
    get "/admin/resources/categories"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(category.name)
  end

  it "creates a category" do
    expect {
      post "/admin/resources/categories", params: { category: { name: "Nova", kind: "expense", user_id: admin.id } }
    }.to change(Category, :count).by(1)
  end

  it "updates a category" do
    category = create(:category, user: admin, name: "Antigo")
    put "/admin/resources/categories/#{category.id}", params: { category: { name: "Atualizado" } }
    expect(category.reload.name).to eq("Atualizado")
  end

  it "destroys a category" do
    category = create(:category, user: admin)
    expect {
      delete "/admin/resources/categories/#{category.id}"
    }.to change(Category, :count).by(-1)
  end
end
