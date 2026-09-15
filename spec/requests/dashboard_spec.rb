require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "shows the current balance and, by default, only this month's history" do
    create(:setting, user: user, initial_balance: 1000)
    category = create(:category, user: user)
    create(:transaction, category: category, user: user, description: "Mercado", amount: 100, kind: :expense, date: Date.current)
    create(:transaction, category: category, user: user, description: "Aluguel atrasado", amount: 50, kind: :expense, date: 3.months.ago.to_date)

    get dashboard_path

    expect(response).to have_http_status(:ok)
    # current_balance is accumulated (unaffected by the history filter)
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(850, unit: "R$ "))
    expect(response.body).to include("Mercado")
    expect(response.body).not_to include("Aluguel atrasado")
  end

  it "shows the full history when the 'all months' filter is selected" do
    create(:setting, user: user)
    category = create(:category, user: user)
    create(:transaction, category: category, user: user, description: "Mercado", amount: 100, kind: :expense, date: Date.current)
    create(:transaction, category: category, user: user, description: "Aluguel atrasado", amount: 50, kind: :expense, date: 3.months.ago.to_date)

    get dashboard_path, params: { month: "all" }

    expect(response.body).to include("Mercado")
    expect(response.body).to include("Aluguel atrasado")
  end

  it "shows only the selected month's history" do
    create(:setting, user: user)
    category = create(:category, user: user)
    target_month = 2.months.ago.to_date
    create(:transaction, category: category, user: user, description: "Mercado", amount: 100, kind: :expense, date: Date.current)
    create(:transaction, category: category, user: user, description: "Conserto do carro", amount: 300, kind: :expense, date: target_month)

    get dashboard_path, params: { month: target_month.strftime("%Y-%m") }

    expect(response.body).to include("Conserto do carro")
    expect(response.body).not_to include("Mercado")
  end

  it "redirects to sign in when not authenticated" do
    sign_out user
    get dashboard_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows navigation links" do
    create(:setting, user: user)

    get dashboard_path

    expect(response.body).to include(categories_path)
    expect(response.body).to include(transactions_path)
    expect(response.body).to include(recurring_entries_path)
  end

  it "includes a mobile nav toggle that reveals the navigation links below the md breakpoint" do
    create(:setting, user: user)

    get dashboard_path

    expect(response.body).to include('id="nav-menu-toggle"')
    expect(response.body).to include('for="nav-menu-toggle"')
    expect(response.body).to include('aria-label="Abrir menu"')
  end

  it "shows a link to the account settings screen" do
    create(:setting, user: user)

    get dashboard_path

    expect(response.body).to include(edit_user_registration_path)
  end

  it "points the confidence filter buttons at the scoped dashboard_confidence path" do
    create(:setting, user: user)

    get dashboard_path

    expect(response.body).to include(%(data-dashboard-filter-url-value="#{dashboard_confidence_path}"))
  end

  it "shows the selected period's income and expense totals" do
    create(:setting, user: user)
    # Two transactions per kind, no single one equal to the total, so the
    # assertions below can only pass if a *summed* total is rendered
    # somewhere — not just each transaction's own line in the list below.
    expense_category = create(:category, user: user, kind: :expense)
    income_category = create(:category, user: user, kind: :income)
    create(:transaction, category: expense_category, user: user, kind: :expense, amount: 40, date: Date.current)
    create(:transaction, category: expense_category, user: user, kind: :expense, amount: 60, date: Date.current)
    create(:transaction, category: income_category, user: user, kind: :income, amount: 150, date: Date.current)
    create(:transaction, category: income_category, user: user, kind: :income, amount: 200, date: Date.current)

    get dashboard_path, params: { month: "all" }

    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(100, unit: "R$ "))
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(350, unit: "R$ "))
  end

  it "changes the totals when a different month is selected" do
    create(:setting, user: user)
    category = create(:category, user: user, kind: :expense)
    older_month = 2.months.ago.to_date
    create(:transaction, category: category, user: user, kind: :expense, amount: 999, date: Date.current)
    create(:transaction, category: category, user: user, kind: :expense, amount: 77, date: older_month)

    get dashboard_path, params: { month: older_month.strftime("%Y-%m") }

    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(77, unit: "R$ "))
    expect(response.body).not_to include(ActionController::Base.helpers.number_to_currency(999, unit: "R$ "))
  end

  it "shows the financial health KPI card with the income/expense breakdown and a status badge" do
    create(:setting, user: user, initial_balance: 1000)
    category = create(:category, user: user)
    create(:recurring_entry, category: category, user: user, kind: :expense, amount: 100, day_of_month: 25, start_date: Date.new(2026, 1, 1))
    create(:recurring_entry, category: category, user: user, kind: :income, amount: 300, day_of_month: 28, start_date: Date.new(2026, 1, 1))

    travel_to Date.new(2026, 3, 10) do
      get dashboard_path
    end

    expect(response.body).to include("Previsão fim do mês")
    expect(response.body).to include("Saudável")
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(1000, unit: "R$ ")) # saldo atual
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(300, unit: "R$ "))  # receita prevista
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(100, unit: "R$ "))  # despesa prevista
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(1200, unit: "R$ ")) # saldo projetado
  end

  it "marks a future-dated transaction as Previsto and a past one as Confirmado" do
    create(:setting, user: user)
    category = create(:category, user: user)
    create(:transaction, category: category, user: user, description: "Salário", amount: 3000, kind: :income, date: Date.current + 5.days)
    create(:transaction, category: category, user: user, description: "Mercado", amount: 100, kind: :expense, date: Date.current)

    get dashboard_path, params: { month: "all" }

    doc = Nokogiri::HTML(response.body)
    salario_row = doc.css("tr").find { |tr| tr.text.include?("Salário") }
    mercado_row = doc.css("tr").find { |tr| tr.text.include?("Mercado") }

    expect(salario_row.text).to include("Previsto")
    expect(mercado_row.text).to include("Confirmado")
  end

  it "shows this month's revenue progress split between confirmed and pending, ignoring the month filter" do
    create(:setting, user: user)
    income_category = create(:category, user: user, kind: :income)

    travel_to Date.new(2026, 3, 10) do
      create(:transaction, category: income_category, user: user, kind: :income, amount: 400, date: Date.new(2026, 3, 5))
      create(:recurring_entry, category: income_category, user: user, kind: :income, amount: 600, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      # Older income, outside March — must not affect the "this month" totals below.
      create(:transaction, category: income_category, user: user, kind: :income, amount: 9999, date: Date.new(2026, 1, 5))

      get dashboard_path, params: { month: "all" }
    end

    doc = Nokogiri::HTML(response.body)
    card = doc.css("div").find { |d| d.text.include?("Progresso de Arrecadação") }

    expect(card.text).to include("Recebido: #{ActionController::Base.helpers.number_to_currency(400, unit: "R$ ")}")
    expect(card.text).to include("A Receber: #{ActionController::Base.helpers.number_to_currency(600, unit: "R$ ")}")
    expect(card.text).to include("Total esperado: #{ActionController::Base.helpers.number_to_currency(1000, unit: "R$ ")}")
    expect(card.to_html).to include("width: 40.0%").and include("width: 60.0%")
  end

  it "shows a zero-width revenue progress bar when there is no expected income this month" do
    create(:setting, user: user)
    create(:category, user: user, kind: :income)

    travel_to Date.new(2026, 3, 10) do
      get dashboard_path, params: { month: "all" }
    end

    doc = Nokogiri::HTML(response.body)
    card = doc.css("div").find { |d| d.text.include?("Progresso de Arrecadação") }

    expect(card.to_html.scan("width: 0%").size).to eq(2)
  end

  it "excludes expense transactions from the revenue progress totals" do
    create(:setting, user: user)
    income_category = create(:category, user: user, kind: :income)
    expense_category = create(:category, user: user, kind: :expense)

    travel_to Date.new(2026, 3, 10) do
      create(:transaction, category: income_category, user: user, kind: :income, amount: 400, date: Date.new(2026, 3, 5))
      create(:transaction, category: expense_category, user: user, kind: :expense, amount: 5000, date: Date.new(2026, 3, 6))

      get dashboard_path
    end

    expect(response.body).not_to include(ActionController::Base.helpers.number_to_currency(5400, unit: "R$ "))
  end

  it "renders the cash flow chart canvas with the current month's series data" do
    create(:setting, user: user, initial_balance: 1000)
    category = create(:category, user: user)
    create(:recurring_entry, category: category, user: user, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))

    travel_to Date.new(2026, 3, 10) do
      get dashboard_path
    end

    expect(response.body).to include('data-controller="chart"')
    expect(response.body).to include("data-chart-labels-value")
    expect(response.body).to include("data-chart-datasets-value")
    expect(response.body).to include("700.0") # projected balance on day 25 shows up in the projected dataset's JSON
  end

  it "keeps the month/category filter form and Resumo/Histórico inside the same turbo frame" do
    create(:setting, user: user)

    get dashboard_path

    doc = Nokogiri::HTML(response.body)
    frame = doc.at_css("turbo-frame#resumo_historico")

    expect(frame).not_to be_nil
    expect(frame.at_css("form")).not_to be_nil
    expect(frame.text).to include("Resumo").and include("Histórico")
  end

  it "returns only the resumo_historico frame content when the filter form is submitted as a frame request" do
    create(:setting, user: user)
    category = create(:category, user: user)
    target_month = 2.months.ago.to_date
    create(:transaction, category: category, user: user, description: "Mercado", amount: 100, kind: :expense, date: Date.current)
    create(:transaction, category: category, user: user, description: "Conserto do carro", amount: 300, kind: :expense, date: target_month)

    get dashboard_path, params: { month: target_month.strftime("%Y-%m") }, headers: { "Turbo-Frame" => "resumo_historico" }

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML(response.body)
    frame = doc.at_css("turbo-frame#resumo_historico")

    expect(frame.text).to include("Conserto do carro")
    expect(frame.text).not_to include("Mercado")
  end

  it "renders both a desktop table and a mobile card list for the Histórico transactions" do
    create(:setting, user: user)
    category = create(:category, user: user)
    create(:transaction, category: category, user: user, description: "Mercado")

    get dashboard_path

    expect(response.body).to include('data-testid="history-table"')
    expect(response.body).to include('data-testid="history-cards"')
    expect(response.body.scan("Mercado").count).to eq(2)
  end

  it "omits the visible category and status badge from the Histórico mobile card, keeping only date, description and amount (with a screen-reader-only status label)" do
    create(:setting, user: user)
    category = create(:category, user: user, name: "Categoria Só Da Tabela")
    create(:transaction, category: category, user: user, description: "Mercado", amount: 100, kind: :expense, date: Date.current)

    get dashboard_path

    doc = Nokogiri::HTML(response.body)
    cards = doc.at_css('[data-testid="history-cards"]')

    expect(cards.text).to include("Mercado")
    expect(cards.text).to include(ActionController::Base.helpers.number_to_currency(100, unit: "R$ "))
    expect(cards.text).not_to include("Categoria Só Da Tabela")
    expect(cards.css("span.rounded-full")).to be_empty
    expect(cards.at_css("span.sr-only").text).to eq("Confirmado")
    expect(cards.text).not_to include("Previsto")
  end

  it "keeps the dashed-border styling on a future transaction's mobile card even without the Previsto badge text" do
    create(:setting, user: user)
    category = create(:category, user: user)
    create(:transaction, category: category, user: user, description: "Salário futuro", kind: :income, date: Date.current + 5.days)

    get dashboard_path, params: { month: "all" }

    doc = Nokogiri::HTML(response.body)
    cards = doc.at_css('[data-testid="history-cards"]')
    future_card = cards.css("div").find { |d| d.text.include?("Salário futuro") }

    expect(future_card["class"]).to include("border-dashed")
  end

  it "does not leak another user's transactions into the history" do
    create(:setting, user: user)
    other_category = create(:category)
    create(:transaction, category: other_category, user: other_category.user, description: "Segredo de outro usuário", amount: 100, kind: :expense, date: Date.current)

    get dashboard_path, params: { month: "all" }

    expect(response.body).not_to include("Segredo de outro usuário")
  end

  describe "GET /dashboard_confidence" do
    it "returns a turbo stream replacing the KPI card with the confirmed-only balance" do
      create(:setting, user: user, initial_balance: 1000)
      category = create(:category, user: user)
      create(:recurring_entry, category: category, user: user, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))

      travel_to Date.new(2026, 3, 10) do
        get dashboard_confidence_path, params: { confidence: "confirmed" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('turbo-stream action="replace" target="financial_health_kpi"')
      expect(response.body).to include(ActionController::Base.helpers.number_to_currency(1000, unit: "R$ "))
      expect(response.body).not_to include(ActionController::Base.helpers.number_to_currency(700, unit: "R$ "))
      # The breakdown sub-figures must also reconcile with the confirmed-only
      # headline — the 300 pending recurring expense must not still show.
      expect(response.body).not_to include(ActionController::Base.helpers.number_to_currency(300, unit: "R$ "))
    end

    it "returns a turbo stream reflecting future one-off transactions for the all level" do
      create(:setting, user: user, initial_balance: 1000)
      category = create(:category, user: user)
      create(:recurring_entry, category: category, user: user, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:transaction, category: category, user: user, kind: :income, amount: 200, date: Date.new(2026, 3, 15))

      travel_to Date.new(2026, 3, 10) do
        get dashboard_confidence_path, params: { confidence: "all" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      expect(response).to have_http_status(:ok)
      # 1000 (current_balance) - 300 (pending recurring expense) + 200 (future one-off income) = 900
      expect(response.body).to include(ActionController::Base.helpers.number_to_currency(900, unit: "R$ "))
    end

    it "falls back to the recurring level for an unrecognized confidence param" do
      create(:setting, user: user, initial_balance: 1000)
      category = create(:category, user: user)
      create(:recurring_entry, category: category, user: user, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))

      travel_to Date.new(2026, 3, 10) do
        get dashboard_confidence_path, params: { confidence: "bogus" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      expect(response).to have_http_status(:ok)
      # recurring level: 1000 - 300 pending recurring expense = 700
      expect(response.body).to include(ActionController::Base.helpers.number_to_currency(700, unit: "R$ "))
    end

    it "also replaces the cash flow chart with a confidence-specific projected series" do
      create(:setting, user: user, initial_balance: 1000)
      category = create(:category, user: user)
      create(:recurring_entry, category: category, user: user, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))

      travel_to Date.new(2026, 3, 10) do
        get dashboard_confidence_path, params: { confidence: "confirmed" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      expect(response.body).to include('turbo-stream action="replace" target="cash_flow_chart"')
      expect(response.body).not_to include("700.0") # recurring expense ignored under :confirmed
    end

    it "reflects future one-off transactions in the chart's projected series for the all level" do
      create(:setting, user: user, initial_balance: 1000)
      category = create(:category, user: user)
      create(:recurring_entry, category: category, user: user, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:transaction, category: category, user: user, kind: :income, amount: 200, date: Date.new(2026, 3, 15))

      travel_to Date.new(2026, 3, 10) do
        get dashboard_confidence_path, params: { confidence: "all" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      expect(response.body).to include('turbo-stream action="replace" target="cash_flow_chart"')
      expect(response.body).to include("900.0") # last projected value under :all (see Setting spec for the same arithmetic)
    end
  end
end
