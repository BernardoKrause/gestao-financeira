require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "creates a category" do
    expect {
      post categories_path, params: { category: { name: "Alimentação", kind: "expense" } }
    }.to change(Category, :count).by(1)
    expect(response).to redirect_to(categories_path)
    expect(Category.last.user).to eq(user)
  end

  it "does not create a category without a name" do
    expect {
      post categories_path, params: { category: { name: "", kind: "expense" } }
    }.not_to change(Category, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates a category" do
    category = create(:category, user: user)
    patch category_path(category), params: { category: { name: "Novo nome" } }
    expect(category.reload.name).to eq("Novo nome")
  end

  it "destroys a category" do
    category = create(:category, user: user)
    expect { delete category_path(category) }.to change(Category, :count).by(-1)
  end

  it "does not destroy a category that still has transactions, and shows an error" do
    category = create(:category, user: user)
    create(:transaction, category: category, user: user)

    expect { delete category_path(category) }.not_to change(Category, :count)
    expect(response).to redirect_to(categories_path)
    expect(flash[:alert]).to be_present
  end

  it "does not list another user's categories" do
    create(:category, name: "Categoria de outro usuário")

    get categories_path

    expect(response.body).not_to include("Categoria de outro usuário")
  end

  it "returns 404 when trying to view another user's category" do
    other_category = create(:category)
    get category_path(other_category)
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when trying to update another user's category" do
    other_category = create(:category, name: "Original")
    patch category_path(other_category), params: { category: { name: "Hackeado" } }
    expect(response).to have_http_status(:not_found)
    expect(other_category.reload.name).to eq("Original")
  end

  it "returns 404 when trying to destroy another user's category" do
    other_category = create(:category)
    expect { delete category_path(other_category) }.not_to change(Category, :count)
    expect(response).to have_http_status(:not_found)
  end
end
