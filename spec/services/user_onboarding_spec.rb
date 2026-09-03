require "rails_helper"

RSpec.describe UserOnboarding do
  it "creates a setting with zero initial balance" do
    user = create(:user)

    described_class.call(user)

    expect(user.setting).to be_present
    expect(user.setting.initial_balance).to eq(0)
  end

  it "seeds the default expense and income categories" do
    user = create(:user)

    described_class.call(user)

    expect(user.categories.expense.pluck(:name)).to contain_exactly(
      "Aluguel", "Assinatura", "Cartão de Crédito", "Contas de Casa", "Esporte",
      "Estética", "Lanchonete/Restaurante", "Mercado", "Padaria", "Saúde"
    )
    expect(user.categories.income.pluck(:name)).to contain_exactly("Renda Extra", "Salário", "Vendas")
  end
end
