require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "shows the current balance and, by default, only this month's history" do
    Setting.instance.update!(initial_balance: 1000)
    category = create(:category)
    create(:transaction, category: category, description: "Mercado", amount: 100, kind: :expense, date: Date.current)
    create(:transaction, category: category, description: "Aluguel atrasado", amount: 50, kind: :expense, date: 3.months.ago.to_date)

    get root_path

    expect(response).to have_http_status(:ok)
    # current_balance is accumulated (unaffected by the history filter)
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(850, unit: "R$ "))
    expect(response.body).to include("Mercado")
    expect(response.body).not_to include("Aluguel atrasado")
  end

  it "shows the full history when the 'all months' filter is selected" do
    category = create(:category)
    create(:transaction, category: category, description: "Mercado", amount: 100, kind: :expense, date: Date.current)
    create(:transaction, category: category, description: "Aluguel atrasado", amount: 50, kind: :expense, date: 3.months.ago.to_date)

    get root_path, params: { month: "all" }

    expect(response.body).to include("Mercado")
    expect(response.body).to include("Aluguel atrasado")
  end

  it "shows only the selected month's history" do
    category = create(:category)
    target_month = 2.months.ago.to_date
    create(:transaction, category: category, description: "Mercado", amount: 100, kind: :expense, date: Date.current)
    create(:transaction, category: category, description: "Conserto do carro", amount: 300, kind: :expense, date: target_month)

    get root_path, params: { month: target_month.strftime("%Y-%m") }

    expect(response.body).to include("Conserto do carro")
    expect(response.body).not_to include("Mercado")
  end

  it "redirects to sign in when not authenticated" do
    sign_out user
    get root_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows navigation links" do
    get root_path

    expect(response.body).to include(categories_path)
    expect(response.body).to include(transactions_path)
    expect(response.body).to include(recurring_entries_path)
  end

  it "shows the selected period's income and expense totals" do
    # Two transactions per kind, no single one equal to the total, so the
    # assertions below can only pass if a *summed* total is rendered
    # somewhere — not just each transaction's own line in the list below.
    expense_category = create(:category, kind: :expense)
    income_category = create(:category, kind: :income)
    create(:transaction, category: expense_category, kind: :expense, amount: 40, date: Date.current)
    create(:transaction, category: expense_category, kind: :expense, amount: 60, date: Date.current)
    create(:transaction, category: income_category, kind: :income, amount: 150, date: Date.current)
    create(:transaction, category: income_category, kind: :income, amount: 200, date: Date.current)

    get root_path, params: { month: "all" }

    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(100, unit: "R$ "))
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(350, unit: "R$ "))
  end

  it "changes the totals when a different month is selected" do
    category = create(:category, kind: :expense)
    older_month = 2.months.ago.to_date
    create(:transaction, category: category, kind: :expense, amount: 999, date: Date.current)
    create(:transaction, category: category, kind: :expense, amount: 77, date: older_month)

    get root_path, params: { month: older_month.strftime("%Y-%m") }

    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(77, unit: "R$ "))
    expect(response.body).not_to include(ActionController::Base.helpers.number_to_currency(999, unit: "R$ "))
  end

  it "shows the financial health KPI card with the income/expense breakdown and a status badge" do
    Setting.instance.update!(initial_balance: 1000)
    category = create(:category)
    create(:recurring_entry, category: category, kind: :expense, amount: 100, day_of_month: 25, start_date: Date.new(2026, 1, 1))
    create(:recurring_entry, category: category, kind: :income, amount: 300, day_of_month: 28, start_date: Date.new(2026, 1, 1))

    travel_to Date.new(2026, 3, 10) do
      get root_path
    end

    expect(response.body).to include("Previsão fim do mês")
    expect(response.body).to include("Saudável")
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(1000, unit: "R$ ")) # saldo atual
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(300, unit: "R$ "))  # receita prevista
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(100, unit: "R$ "))  # despesa prevista
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(1200, unit: "R$ ")) # saldo projetado
  end

  it "marks a future-dated transaction as Previsto and a past one as Confirmado" do
    category = create(:category)
    create(:transaction, category: category, description: "Salário", amount: 3000, kind: :income, date: Date.current + 5.days)
    create(:transaction, category: category, description: "Mercado", amount: 100, kind: :expense, date: Date.current)

    get root_path, params: { month: "all" }

    doc = Nokogiri::HTML(response.body)
    salario_row = doc.css("tr").find { |tr| tr.text.include?("Salário") }
    mercado_row = doc.css("tr").find { |tr| tr.text.include?("Mercado") }

    expect(salario_row.text).to include("Previsto")
    expect(mercado_row.text).to include("Confirmado")
  end

  it "shows this month's revenue progress split between confirmed and pending, ignoring the month filter" do
    income_category = create(:category, kind: :income)

    travel_to Date.new(2026, 3, 10) do
      create(:transaction, category: income_category, kind: :income, amount: 400, date: Date.new(2026, 3, 5))
      create(:recurring_entry, category: income_category, kind: :income, amount: 600, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      # Older income, outside March — must not affect the "this month" totals below.
      create(:transaction, category: income_category, kind: :income, amount: 9999, date: Date.new(2026, 1, 5))

      get root_path, params: { month: "all" }
    end

    doc = Nokogiri::HTML(response.body)
    card = doc.css("div").find { |d| d.text.include?("Progresso de Arrecadação") }

    expect(card.text).to include("Recebido: #{ActionController::Base.helpers.number_to_currency(400, unit: "R$ ")}")
    expect(card.text).to include("A Receber: #{ActionController::Base.helpers.number_to_currency(600, unit: "R$ ")}")
    expect(card.text).to include("Total esperado: #{ActionController::Base.helpers.number_to_currency(1000, unit: "R$ ")}")
    expect(card.to_html).to include("width: 40.0%").and include("width: 60.0%")
  end

  it "shows a zero-width revenue progress bar when there is no expected income this month" do
    create(:category, kind: :income)

    travel_to Date.new(2026, 3, 10) do
      get root_path, params: { month: "all" }
    end

    doc = Nokogiri::HTML(response.body)
    card = doc.css("div").find { |d| d.text.include?("Progresso de Arrecadação") }

    expect(card.to_html.scan("width: 0%").size).to eq(2)
  end

  it "excludes expense transactions from the revenue progress totals" do
    income_category = create(:category, kind: :income)
    expense_category = create(:category, kind: :expense)

    travel_to Date.new(2026, 3, 10) do
      create(:transaction, category: income_category, kind: :income, amount: 400, date: Date.new(2026, 3, 5))
      create(:transaction, category: expense_category, kind: :expense, amount: 5000, date: Date.new(2026, 3, 6))

      get root_path
    end

    expect(response.body).not_to include(ActionController::Base.helpers.number_to_currency(5400, unit: "R$ "))
  end

  describe "GET /dashboard_confidence" do
    it "returns a turbo stream replacing the KPI card with the confirmed-only balance" do
      Setting.instance.update!(initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))

      travel_to Date.new(2026, 3, 10) do
        get dashboard_confidence_path, params: { confidence: "confirmed" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('turbo-stream action="replace" target="financial_health_kpi"')
      expect(response.body).to include(ActionController::Base.helpers.number_to_currency(1000, unit: "R$ "))
      expect(response.body).not_to include(ActionController::Base.helpers.number_to_currency(700, unit: "R$ "))
    end

    it "falls back to the recurring level for an unrecognized confidence param" do
      Setting.instance.update!(initial_balance: 1000)

      get dashboard_confidence_path, params: { confidence: "bogus" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
    end
  end
end
