# Fase 1 — Card de Saúde Financeira (KPI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the plain "Saldo" table on the dashboard with a KPI card that shows the projected end-of-month balance, its income/expense breakdown, and a derived health badge (Saudável/Atenção/Crítico).

**Architecture:** Split `Setting#projected_month_end_balance`'s private pending-recurring sum into two public methods (income/expense), add a `financial_health_status` classifier, expose both through the existing `DashboardData` concern, and render a new partial that replaces the current "Saldo" section in `dashboard/index.html.erb`. No new tables, no JS — same request/response pattern as the rest of the dashboard.

**Tech Stack:** Rails 8, RSpec + FactoryBot + Capybara (request specs), Tailwind CSS v4 (utility classes only, no new custom CSS needed).

## Global Constraints

- Do not touch `RecurringEntry`/`Transaction` one-off logic — this phase only adds read methods to `Setting`.
- Preserve the existing scope decision documented in project memory: the month-end projection counts **only** active recurring entries, never future-dated one-off `Transaction` rows. `projected_month_end_balance`'s numeric result must not change for any existing input.
- Follow existing dashboard convention: computed values are exposed as controller `@ivars` set in `DashboardData#load_dashboard_data`, consumed directly by ERB partials — no view components, no per-request JSON.
- Currency formatting always via `number_to_currency(value, unit: "R$ ")`, matching every other money value on the dashboard.
- All new Ruby is plain `ActiveRecord`/Ruby — no service objects for a 4-line calculation.

---

### Task 1: Split pending-recurring total into income/expense and add health status

**Files:**
- Modify: `app/models/setting.rb`
- Test: `spec/models/setting_spec.rb`

**Interfaces:**
- Produces: `Setting#pending_recurring_income_total(as_of: Date.current) -> Numeric`, `Setting#pending_recurring_expense_total(as_of: Date.current) -> Numeric`, `Setting#financial_health_status(as_of: Date.current) -> Symbol` (`:healthy`, `:warning`, or `:critical`).
- `Setting#projected_month_end_balance` keeps its existing signature and must return numerically identical results to today's implementation for every existing spec.

- [ ] **Step 1: Write the failing tests for the split totals**

Add to `spec/models/setting_spec.rb`, inside the existing `RSpec.describe Setting` block (after the `#projected_month_end_balance` block):

```ruby
  describe "#pending_recurring_income_total" do
    it "sums only pending income entries" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.pending_recurring_income_total(as_of: Date.new(2026, 3, 10))).to eq(500)
    end
  end

  describe "#pending_recurring_expense_total" do
    it "sums only pending expense entries" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.pending_recurring_expense_total(as_of: Date.new(2026, 3, 10))).to eq(300)
    end
  end

  describe "#financial_health_status" do
    it "is :critical when the projected balance is negative" do
      setting = create(:setting, initial_balance: 100)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 500, day_of_month: 25, start_date: Date.new(2026, 1, 1))

      expect(setting.financial_health_status(as_of: Date.new(2026, 3, 10))).to eq(:critical)
    end

    it "is :warning when the projected balance is non-negative but lower than the current balance" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 100, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.financial_health_status(as_of: Date.new(2026, 3, 10))).to eq(:warning)
    end

    it "is :healthy when the projected balance is at or above the current balance" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 100, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 300, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.financial_health_status(as_of: Date.new(2026, 3, 10))).to eq(:healthy)
    end

    it "is :healthy at the boundary where projected equals current (flat month)" do
      setting = create(:setting, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, category: category, kind: :expense, amount: 200, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, category: category, kind: :income, amount: 200, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(setting.financial_health_status(as_of: Date.new(2026, 3, 10))).to eq(:healthy)
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/models/setting_spec.rb -e "pending_recurring_income_total" -e "pending_recurring_expense_total" -e "financial_health_status"`
Expected: FAIL — `NoMethodError: undefined method 'pending_recurring_income_total'` (and similarly for the other two methods).

- [ ] **Step 3: Implement the split totals and health classifier**

Replace the full contents of `app/models/setting.rb` with:

```ruby
class Setting < ApplicationRecord
  validates :initial_balance, numericality: true

  def self.instance
    first_or_create!(initial_balance: 0)
  end

  def current_balance(as_of: Date.current)
    initial_balance + Transaction.where(date: ..as_of).sum(&:signed_amount)
  end

  def projected_month_end_balance(as_of: Date.current)
    current_balance(as_of: as_of) +
      pending_recurring_income_total(as_of: as_of) -
      pending_recurring_expense_total(as_of: as_of)
  end

  def pending_recurring_income_total(as_of: Date.current)
    pending_recurring_entries(as_of: as_of).select(&:income?).sum(&:amount)
  end

  def pending_recurring_expense_total(as_of: Date.current)
    pending_recurring_entries(as_of: as_of).select(&:expense?).sum(&:amount)
  end

  def financial_health_status(as_of: Date.current)
    projected = projected_month_end_balance(as_of: as_of)
    return :critical if projected.negative?
    return :warning if projected < current_balance(as_of: as_of)

    :healthy
  end

  private

  def pending_recurring_entries(as_of:)
    return [] if as_of.day == as_of.end_of_month.day

    RecurringEntry.active.select { |entry| pending?(entry, as_of) }
  end

  def pending?(entry, as_of)
    return false unless entry.day_of_month > as_of.day

    fire_date = Date.new(as_of.year, as_of.month, [ entry.day_of_month, as_of.end_of_month.day ].min)
    entry.start_date <= fire_date && (entry.end_date.nil? || entry.end_date >= fire_date)
  end
end
```

- [ ] **Step 4: Run all Setting specs to verify everything passes, including the pre-existing ones**

Run: `bundle exec rspec spec/models/setting_spec.rb`
Expected: PASS — all examples green, including the four pre-existing `#projected_month_end_balance` examples (proves the refactor didn't change behavior).

- [ ] **Step 5: Commit**

```bash
git add app/models/setting.rb spec/models/setting_spec.rb
git commit -m "feat: split pending recurring totals and add financial health status to Setting"
```

---

### Task 2: Expose the new values on the dashboard and render the KPI card

**Files:**
- Modify: `app/controllers/concerns/dashboard_data.rb`
- Create: `app/views/dashboard/_financial_health_kpi.html.erb`
- Modify: `app/views/dashboard/index.html.erb`
- Test: `spec/requests/dashboard_spec.rb`

**Interfaces:**
- Consumes: `Setting#pending_recurring_income_total`, `Setting#pending_recurring_expense_total`, `Setting#financial_health_status` (Task 1).
- Produces: ivars `@receita_prevista`, `@despesa_prevista`, `@financial_health_status` available to `dashboard/index.html.erb` and its partials.

- [ ] **Step 1: Write the failing request spec**

Add to `spec/requests/dashboard_spec.rb`, inside the `RSpec.describe "Dashboard"` block:

```ruby
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
```

`travel_to` needs `ActiveSupport::Testing::TimeHelpers` included in RSpec. Open `spec/rails_helper.rb` and add this line inside the existing `RSpec.configure do |config|` block, next to the other `config.include` lines (around line 73-74):

```ruby
  config.include ActiveSupport::Testing::TimeHelpers
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "financial health KPI"`
Expected: FAIL — `NoMethodError: undefined method 'travel_to'` before the include is added; after adding the include, FAIL on the "Previsão fim do mês" (or currency) assertion because the ivars/partial don't exist yet.

- [ ] **Step 3: Expose the new ivars in DashboardData**

In `app/controllers/concerns/dashboard_data.rb`, modify `load_dashboard_data` (replace lines 8-25):

```ruby
  def load_dashboard_data
    @today = Date.current
    @setting = Setting.instance
    @current_balance = @setting.current_balance(as_of: @today)
    @receita_prevista = @setting.pending_recurring_income_total(as_of: @today)
    @despesa_prevista = @setting.pending_recurring_expense_total(as_of: @today)
    @projected_balance = @setting.projected_month_end_balance(as_of: @today)
    @financial_health_status = @setting.financial_health_status(as_of: @today)

    @selected_month = params[:month].presence || current_month_value
    @month_options = build_month_options
    @selected_month_label = @month_options.find { |_label, value| value == @selected_month }&.first

    @selected_category_id = params[:category_id].presence
    @category_options = Category.order(:name).pluck(:name, :id)

    # Resumo and Histórico both reflect the same selected period and category.
    @transactions = filtered_transactions
    @month_income_total = @transactions.select(&:income?).sum(&:amount)
    @month_expense_total = @transactions.select(&:expense?).sum(&:amount)
  end
```

- [ ] **Step 4: Create the KPI card partial**

Create `app/views/dashboard/_financial_health_kpi.html.erb`:

```erb
<% badge = {
     healthy: { label: "Saudável", classes: "bg-emerald-500/20 text-emerald-300 border-emerald-500/30" },
     warning: { label: "Atenção", classes: "bg-amber-500/20 text-amber-300 border-amber-500/30" },
     critical: { label: "Crítico", classes: "bg-rose-500/20 text-rose-300 border-rose-500/30" }
   }.fetch(@financial_health_status) %>

<div class="relative mb-6 overflow-hidden rounded-2xl bg-gradient-to-br from-slate-900 to-slate-800 p-6 text-white shadow-lg">
  <div class="pointer-events-none absolute -bottom-10 -right-10 h-40 w-40 rounded-full bg-emerald-500/10 blur-2xl"></div>

  <div class="flex flex-col justify-between gap-4 md:flex-row md:items-center">
    <div>
      <div class="mb-1 flex items-center gap-2">
        <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Previsão fim do mês</span>
        <span class="rounded-full border px-2.5 py-0.5 text-xs font-medium <%= badge[:classes] %>">
          ● <%= badge[:label] %>
        </span>
      </div>
      <h2 class="text-3xl font-extrabold tracking-tight text-white">
        <%= number_to_currency(@projected_balance, unit: "R$ ") %>
      </h2>
    </div>

    <div class="grid grid-cols-3 gap-3 rounded-xl border border-slate-700/50 bg-slate-800/80 p-3 text-xs">
      <div>
        <p class="text-slate-400">Saldo atual</p>
        <p class="font-bold text-slate-200"><%= number_to_currency(@current_balance, unit: "R$ ") %></p>
      </div>
      <div class="border-l border-slate-700/60 pl-3">
        <p class="text-emerald-400">+ Entradas pend.</p>
        <p class="font-bold text-emerald-300"><%= number_to_currency(@receita_prevista, unit: "R$ ") %></p>
      </div>
      <div class="border-l border-slate-700/60 pl-3">
        <p class="text-rose-400">- Saídas pend.</p>
        <p class="font-bold text-rose-300"><%= number_to_currency(@despesa_prevista, unit: "R$ ") %></p>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 5: Replace the "Saldo" table with the KPI card**

In `app/views/dashboard/index.html.erb`, replace the "Saldo" `<h2>` and `<table>` block (current lines 14-26):

```erb
<h2 class="mb-2 mt-2 text-xl font-semibold">Saldo</h2>
<table class="mb-6 w-full bg-white text-sm">
  <tbody>
    <tr>
      <td class="border px-3 py-2">Saldo atual</td>
      <td class="border px-3 py-2 font-semibold"><%= number_to_currency(@current_balance, unit: "R$ ") %></td>
    </tr>
    <tr>
      <td class="border px-3 py-2">Previsto até o fim do mês</td>
      <td class="border px-3 py-2 font-semibold"><%= number_to_currency(@projected_balance, unit: "R$ ") %></td>
    </tr>
  </tbody>
</table>
```

with:

```erb
<%= render "dashboard/financial_health_kpi" %>
```

- [ ] **Step 6: Run the full dashboard request spec suite**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: PASS — the new example passes, and every pre-existing example still passes (they only assert on currency substrings and text present anywhere in the body, which the new card still renders).

- [ ] **Step 7: Commit**

```bash
git add app/controllers/concerns/dashboard_data.rb app/views/dashboard/_financial_health_kpi.html.erb app/views/dashboard/index.html.erb spec/requests/dashboard_spec.rb spec/rails_helper.rb
git commit -m "feat: show financial health KPI card on the dashboard"
```

---

## Self-Review Notes

- **Spec coverage:** Fase 1's calculations (saldo_atual, receita_prevista, despesa_prevista, saldo_projetado) and the status badge are both covered (Task 1 model methods, Task 2 view). The gradient/badge markup mirrors the original spec's example, adapted to this app's real ivars.
- **Deviation from the original spec, intentional:** the health-status thresholds (`:healthy`/`:warning`/`:critical`) are a new rule not specified in the source document, since it only showed a static "Saudável" placeholder — defined explicitly above (critical if projected < 0, warning if projected < current, healthy otherwise) so a reviewer can dispute the exact thresholds without ambiguity about what shipped.
- **No placeholders:** every step has runnable code and exact file content.
