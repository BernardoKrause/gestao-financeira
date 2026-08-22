require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "creates a category" do
    expect {
      post categories_path, params: { category: { name: "Alimentação", kind: "expense" } }
    }.to change(Category, :count).by(1)
    expect(response).to redirect_to(categories_path)
  end

  it "does not create a category without a name" do
    expect {
      post categories_path, params: { category: { name: "", kind: "expense" } }
    }.not_to change(Category, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates a category" do
    category = create(:category)
    patch category_path(category), params: { category: { name: "Novo nome" } }
    expect(category.reload.name).to eq("Novo nome")
  end

  it "destroys a category" do
    category = create(:category)
    expect { delete category_path(category) }.to change(Category, :count).by(-1)
  end

  it "does not destroy a category that still has transactions, and shows an error" do
    category = create(:category)
    create(:transaction, category: category)

    expect { delete category_path(category) }.not_to change(Category, :count)
    expect(response).to redirect_to(categories_path)
    expect(flash[:alert]).to be_present
  end
end
