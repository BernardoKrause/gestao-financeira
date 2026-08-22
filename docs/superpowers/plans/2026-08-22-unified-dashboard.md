# Unified Dashboard (Quick Entry) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the dashboard into the daily-use hub: show this month's income/expense totals alongside the existing balances, and let the user create a one-off or fixed (recurring) expense/income directly from the dashboard via two inline quick-entry forms, without navigating away.

**Architecture:** A shared `DashboardData` controller concern centralizes the data-loading logic so both `DashboardController#index` and the new `QuickEntriesController#create` (on validation failure) can render the same full dashboard. `QuickEntriesController#create` creates either a `Transaction` (one-off) or a `RecurringEntry` (fixed — and immediately runs the existing `RecurringEntryGenerator` so this month's occurrence shows up right away) based on a `fixed` checkbox, reusing the existing models' validations unchanged.

**Tech Stack:** Ruby on Rails 8.x, plain CSS (`:has()` selector for the fixed/avulso field toggle), native `<details>/<summary>` for the expand/collapse — no new JavaScript, no new gems.

## Global Constraints

- Accounts/Categories/Transactions/RecurringEntries keep their existing separate pages — none are removed from navigation; this plan only changes the dashboard.
- `Account#current_balance`/`#projected_month_end_balance` keep their existing meaning (accumulated since `initial_balance`) — the monthly totals are new, additional figures, not a redefinition.
- No new JavaScript and no new gems — the fixed/avulso field toggle and the form expand/collapse use only `<details>/<summary>` and CSS `:has()`.
- The quick-entry form's category dropdown must only list categories whose `kind` matches the button clicked (expense categories under "Gasto", income categories under "Receita").
- Creating a "fixed" quick entry must both create the `RecurringEntry` AND call `RecurringEntryGenerator.call` in the same request, so this month's transaction appears immediately if due.
- Tests via RSpec; every task ships with passing tests before moving on.

---

### Task 1: Dashboard data concern + monthly income/expense totals

**Files:**
- Create: `app/controllers/concerns/dashboard_data.rb`
- Modify: `app/controllers/dashboard_controller.rb`
- Modify: `app/views/dashboard/index.html.erb`
- Test: `spec/requests/dashboard_spec.rb`

**Interfaces:**
- Consumes: `Account#current_balance`/`#projected_month_end_balance` (existing), `Transaction#income?`/`#expense?` (existing, from the `kind` enum).
- Produces: `DashboardData` concern with a private `load_dashboard_data` method that sets `@today`, `@accounts`, `@total_current_balance`, `@total_projected_balance`, `@transactions`, `@month_income_total`, `@month_expense_total`. Used by Task 2's `QuickEntriesController`.

- [ ] **Step 1: Write the failing request spec**

Append to `spec/requests/dashboard_spec.rb`, inside the existing `RSpec.describe "Dashboard"` block:

```ruby
  it "shows the month's income and expense totals" do
    account = create(:account)
    expense_category = create(:category, kind: :expense)
    income_category = create(:category, kind: :income)
    create(:transaction, account: account, category: expense_category, kind: :expense, amount: 100, date: Date.current)
    create(:transaction, account: account, category: income_category, kind: :income, amount: 350, date: Date.current)

    get root_path

    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(100, unit: "R$ "))
    expect(response.body).to include(ActionController::Base.helpers.number_to_currency(350, unit: "R$ "))
  end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Expected: FAIL — the totals aren't rendered yet (the two `number_to_currency` strings won't be found, or coincidentally only one will).

- [ ] **Step 3: Extract the concern**

Create `app/controllers/concerns/dashboard_data.rb`:

```ruby
module DashboardData
  extend ActiveSupport::Concern

  private

  def load_dashboard_data
    @today = Date.current
    @accounts = Account.order(:name)
    @total_current_balance = @accounts.sum { |account| account.current_balance(as_of: @today) }
    @total_projected_balance = @accounts.sum { |account| account.projected_month_end_balance(as_of: @today) }
    @transactions = Transaction.includes(:account, :category)
                                .where(date: @today.beginning_of_month..@today.end_of_month)
                                .order(date: :desc)
    @month_income_total = @transactions.select(&:income?).sum(&:amount)
    @month_expense_total = @transactions.select(&:expense?).sum(&:amount)
  end
end
```

- [ ] **Step 4: Use the concern in DashboardController**

Replace the contents of `app/controllers/dashboard_controller.rb`:

```ruby
class DashboardController < ApplicationController
  include DashboardData

  def index
    load_dashboard_data
  end
end
```

- [ ] **Step 5: Add the monthly totals to the view**

Edit `app/views/dashboard/index.html.erb`, insert this block between the existing `<table>` (Contas) and the `<h2>Lançamentos do mês</h2>` section:

```erb
<h2>Resumo do mês</h2>
<table>
  <tbody>
    <tr>
      <td>Receitas do mês</td>
      <td><%= number_to_currency(@month_income_total, unit: "R$ ") %></td>
    </tr>
    <tr>
      <td>Gastos do mês</td>
      <td><%= number_to_currency(@month_expense_total, unit: "R$ ") %></td>
    </tr>
  </tbody>
</table>
```

- [ ] **Step 6: Run to verify it passes**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Expected: all examples pass.

- [ ] **Step 7: Run the full suite**

```bash
bundle exec rspec
```

Expected: all examples pass.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Extract dashboard data into a shared concern; add monthly income/expense totals"
```

---

### Task 2: QuickEntriesController — create a Transaction or RecurringEntry

**Files:**
- Create: `app/controllers/quick_entries_controller.rb`
- Modify: `config/routes.rb`
- Test: `spec/requests/quick_entries_spec.rb`

**Interfaces:**
- Consumes: `DashboardData#load_dashboard_data` (Task 1), `Transaction`/`RecurringEntry` models (existing, unchanged), `RecurringEntryGenerator.call` (existing).
- Produces: `POST /quick_entries` (`quick_entries_path`) → `QuickEntriesController#create`. Reads flat (non-namespaced) params: `kind` ("expense"/"income"), `fixed` ("1" or absent), `description`, `amount`, `account_id`, `category_id`, and either `date` (when not fixed) or `day_of_month` (when fixed). On success: creates the record, redirects to `root_path`. On failure: sets `@quick_entry_kind` (= `params[:kind]`) and `@quick_entry_record` (the invalid `Transaction` or `RecurringEntry`), calls `load_dashboard_data`, and renders `"dashboard/index"` with `status: :unprocessable_entity`. Used by Task 3's dashboard view to reopen the right form with errors.

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/quick_entries_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "QuickEntries", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account) }
  let(:expense_category) { create(:category, kind: :expense) }
  let(:income_category) { create(:category, kind: :income) }

  before { sign_in user }

  it "creates a one-off expense transaction and redirects to the dashboard" do
    expect {
      post quick_entries_path, params: { kind: "expense", description: "Mercado", amount: 150, date: Date.current, account_id: account.id, category_id: expense_category.id }
    }.to change(Transaction, :count).by(1)

    expect(response).to redirect_to(root_path)
    transaction = Transaction.last
    expect(transaction.kind).to eq("expense")
    expect(transaction.description).to eq("Mercado")
  end

  it "creates a one-off income transaction" do
    expect {
      post quick_entries_path, params: { kind: "income", description: "Freela", amount: 500, date: Date.current, account_id: account.id, category_id: income_category.id }
    }.to change(Transaction, :count).by(1)

    expect(Transaction.last.kind).to eq("income")
  end

  it "creates a fixed expense recurring entry and generates this month's transaction immediately" do
    expect {
      post quick_entries_path, params: { kind: "expense", fixed: "1", description: "Aluguel", amount: 1500, day_of_month: Date.current.day, account_id: account.id, category_id: expense_category.id }
    }.to change(RecurringEntry, :count).by(1)

    entry = RecurringEntry.last
    expect(entry.start_date).to eq(Date.current)
    expect(entry.transactions.count).to eq(1)
    expect(response).to redirect_to(root_path)
  end

  it "does not create anything with an invalid amount, and re-renders the dashboard" do
    expect {
      post quick_entries_path, params: { kind: "expense", description: "Mercado", amount: 0, date: Date.current, account_id: account.id, category_id: expense_category.id }
    }.not_to change(Transaction, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/requests/quick_entries_spec.rb
```

Expected: FAIL — no route matches `quick_entries_path`.

- [ ] **Step 3: Add the route**

Edit `config/routes.rb`, add after `resources :recurring_entries`:

```ruby
  post "quick_entries", to: "quick_entries#create", as: :quick_entries
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/quick_entries_controller.rb`:

```ruby
class QuickEntriesController < ApplicationController
  include DashboardData

  def create
    if params[:fixed] == "1"
      create_recurring_entry
    else
      create_transaction
    end
  end

  private

  def create_transaction
    @transaction = Transaction.new(
      description: params[:description],
      amount: params[:amount],
      kind: params[:kind],
      date: params[:date],
      account_id: params[:account_id],
      category_id: params[:category_id]
    )

    if @transaction.save
      redirect_to root_path, notice: "Lançamento registrado."
    else
      render_dashboard_with_error(@transaction)
    end
  end

  def create_recurring_entry
    @recurring_entry = RecurringEntry.new(
      description: params[:description],
      amount: params[:amount],
      kind: params[:kind],
      day_of_month: params[:day_of_month],
      start_date: Date.current,
      account_id: params[:account_id],
      category_id: params[:category_id]
    )

    if @recurring_entry.save
      RecurringEntryGenerator.call
      redirect_to root_path, notice: "Recorrência criada."
    else
      render_dashboard_with_error(@recurring_entry)
    end
  end

  def render_dashboard_with_error(record)
    load_dashboard_data
    @quick_entry_kind = params[:kind]
    @quick_entry_record = record
    render "dashboard/index", status: :unprocessable_entity
  end
end
```

- [ ] **Step 5: Run to verify it passes**

```bash
bundle exec rspec spec/requests/quick_entries_spec.rb
```

Expected: `4 examples, 0 failures`.

- [ ] **Step 6: Run the full suite**

```bash
bundle exec rspec
```

Expected: all examples pass.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Add QuickEntriesController to create transactions/recurring entries from the dashboard"
```

---

### Task 3: Quick-entry forms on the dashboard (view + styling)

**Files:**
- Create: `app/views/dashboard/_quick_entry_form.html.erb`
- Modify: `app/views/dashboard/index.html.erb`
- Modify: `app/assets/stylesheets/application.css`
- Test: `spec/requests/quick_entries_spec.rb`

**Interfaces:**
- Consumes: `quick_entries_path` (Task 2), `@quick_entry_kind`/`@quick_entry_record` (Task 2, set only on validation failure), `Category.expense`/`Category.income` (existing enum scopes).
- Produces: the two visible "Gasto"/"Receita" quick-entry forms on the dashboard. No new interface consumed by later tasks — this is the final task.

- [ ] **Step 1: Write the failing request specs**

Append to `spec/requests/quick_entries_spec.rb`, inside the existing `RSpec.describe "QuickEntries"` block:

```ruby
  it "filters categories by kind in each quick entry form" do
    expense_cat = create(:category, name: "Mercado", kind: :expense)
    income_cat = create(:category, name: "Salário", kind: :income)

    get root_path

    body = response.body
    expense_form = body[/quick-entry--expense.*?<\/details>/m]
    income_form = body[/quick-entry--income.*?<\/details>/m]

    expect(expense_form).to include("Mercado")
    expect(expense_form).not_to include("Salário")
    expect(income_form).to include("Salário")
    expect(income_form).not_to include("Mercado")
  end

  it "reopens the expense form with the validation error after an invalid submission" do
    account = create(:account)
    category = create(:category, kind: :expense)

    post quick_entries_path, params: { kind: "expense", description: "Mercado", amount: 0, date: Date.current, account_id: account.id, category_id: category.id }

    body = response.body
    expense_form = body[/quick-entry--expense.*?<\/details>/m]

    expect(expense_form).to include("error-messages")
    expect(expense_form).to match(/<details open/)
  end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/requests/quick_entries_spec.rb
```

Expected: FAIL — `quick-entry--expense`/`quick-entry--income` don't exist yet in the rendered page.

- [ ] **Step 3: Create the quick-entry form partial**

Create `app/views/dashboard/_quick_entry_form.html.erb`:

```erb
<details<%= " open" if record&.errors&.any? %> class="quick-entry quick-entry--<%= kind %>">
  <summary><%= label %></summary>

  <%= form_with url: quick_entries_path, method: :post do %>
    <% if record&.errors&.any? %>
      <div class="error-messages">
        <ul>
          <% record.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <%= hidden_field_tag :kind, kind %>

    <div>
      <%= label_tag :description, "Descrição" %>
      <%= text_field_tag :description, record&.description %>
    </div>

    <div>
      <%= label_tag :amount, "Valor" %>
      <%= number_field_tag :amount, record&.amount, step: 0.01 %>
    </div>

    <div>
      <%= label_tag :account_id, "Conta" %>
      <%= select_tag :account_id, options_from_collection_for_select(Account.order(:name), :id, :name, record&.account_id) %>
    </div>

    <div>
      <%= label_tag :category_id, "Categoria" %>
      <%= select_tag :category_id, options_from_collection_for_select(categories, :id, :name, record&.category_id) %>
    </div>

    <div class="quick-entry-fixed-toggle">
      <%= check_box_tag :fixed, "1", record.is_a?(RecurringEntry), class: "fixed-toggle", id: "fixed_#{kind}" %>
      <%= label_tag "fixed_#{kind}", "Fixo (recorrente)" %>
    </div>

    <div class="quick-entry-field quick-entry-field--avulso">
      <%= label_tag :date, "Data" %>
      <%= date_field_tag :date, (record.is_a?(Transaction) ? record.date : Date.current) %>
    </div>

    <div class="quick-entry-field quick-entry-field--fixo">
      <%= label_tag :day_of_month, "Dia do mês" %>
      <%= number_field_tag :day_of_month, (record.is_a?(RecurringEntry) ? record.day_of_month : nil), min: 1, max: 31 %>
    </div>

    <%= submit_tag label %>
  <% end %>
</details>
```

- [ ] **Step 4: Render both forms on the dashboard**

Edit `app/views/dashboard/index.html.erb`, insert this block between the "Resumo do mês" table (Task 1) and the `<h2>Lançamentos do mês</h2>` section:

```erb
<h2>Lançar</h2>
<div class="quick-entries">
  <%= render "dashboard/quick_entry_form", kind: "expense", label: "Gasto",
        categories: Category.expense.order(:name),
        record: (@quick_entry_kind == "expense" ? @quick_entry_record : nil) %>

  <%= render "dashboard/quick_entry_form", kind: "income", label: "Receita",
        categories: Category.income.order(:name),
        record: (@quick_entry_kind == "income" ? @quick_entry_record : nil) %>
</div>
```

- [ ] **Step 5: Run to verify it passes**

```bash
bundle exec rspec spec/requests/quick_entries_spec.rb
```

Expected: all examples pass (6 total in this file).

- [ ] **Step 6: Style the quick-entry cards, buttons, and the fixed/avulso CSS-only toggle**

Edit `app/assets/stylesheets/application.css`, append at the end:

```css
/* Quick entries */

.quick-entries {
  display: flex;
  gap: 1rem;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
}

.quick-entry {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 0.5rem;
  flex: 1;
  min-width: 260px;
}

.quick-entry summary {
  cursor: pointer;
  padding: 0.875rem 1rem;
  font-weight: 700;
  color: #ffffff;
  border-radius: 0.5rem;
  list-style: none;
}

.quick-entry summary::-webkit-details-marker {
  display: none;
}

.quick-entry--expense summary {
  background: #dc2626;
}

.quick-entry--income summary {
  background: #16a34a;
}

.quick-entry form {
  border: none;
  border-radius: 0;
  max-width: none;
  margin-bottom: 0;
  background: none;
}

.quick-entry-field--fixo {
  display: none;
}

.quick-entry:has(.fixed-toggle:checked) .quick-entry-field--fixo {
  display: flex;
}

.quick-entry:has(.fixed-toggle:checked) .quick-entry-field--avulso {
  display: none;
}
```

- [ ] **Step 7: Run the full suite**

```bash
bundle exec rspec
```

Expected: all examples pass.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Add quick-entry forms (Gasto/Receita) to the dashboard, with red/green styling"
```

---

## Self-Review Notes

- **Spec coverage:** every requirement in `docs/superpowers/specs/2026-08-22-unified-dashboard-design.md` is covered — monthly totals (Task 1), quick-entry backend for both one-off and fixed, both kinds, with immediate generator run (Task 2), category filtering by kind, CSS-only fixed/avulso toggle, error re-open behavior, and red/green styling (Task 3). Accounts/Categories/Transactions/RecurringEntries pages are untouched by any task, matching the "fora de escopo" section.
- **Type consistency:** `load_dashboard_data` (Task 1) is called identically by `DashboardController#index` and `QuickEntriesController#render_dashboard_with_error` (Task 2). `@quick_entry_kind`/`@quick_entry_record` are set in Task 2 and consumed with the exact same names in Task 3's view. `quick_entries_path` (Task 2's route) is referenced identically in Task 3's form.
- **No placeholders:** all steps contain literal, runnable code.
