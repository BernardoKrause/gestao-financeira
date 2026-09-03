class UserOnboarding
  DEFAULT_CATEGORIES = {
    expense: [ "Aluguel", "Assinatura", "Cartão de Crédito", "Contas de Casa", "Esporte", "Estética", "Lanchonete/Restaurante", "Mercado", "Padaria", "Saúde" ],
    income: [ "Renda Extra", "Salário", "Vendas" ]
  }.freeze

  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    user.create_setting!(initial_balance: 0)
    DEFAULT_CATEGORIES.each do |kind, names|
      names.each { |name| user.categories.create!(name: name, kind: kind) }
    end
  end

  private

  attr_reader :user
end
