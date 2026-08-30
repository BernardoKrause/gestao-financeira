# Fase 2 — Diferenciação Visual de Transações (Histórico vs. Futuro) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the "Histórico" table on the dashboard, visually distinguish transactions already realized (date ≤ today) from ones dated in the future, so the user doesn't mistake a future-dated entry for money already in hand.

**Architecture:** This app has no `paid`/`pending` status column — a one-off `Transaction` is just a row with a `date`, and the quick-entry and full forms both let the user pick any date, including a future one (confirmed by reading `app/controllers/quick_entries_controller.rb` and the `date_field_tag` in `app/views/dashboard/_quick_entry_form.html.erb`). "Future" is therefore derived, not stored: `transaction.date > Date.current`. Add that one predicate to the model, add a "Status" column to the existing Histórico `<table>`, and style future rows with a dashed border + reduced opacity. No new tables, no JS.

**Tech Stack:** Rails 8, RSpec + FactoryBot (model + request specs), Tailwind CSS v4 utility classes.

## Global Constraints

- Depends on Fase 1 being merged first (this plan edits `dashboard/index.html.erb`, which Fase 1 already restructured).
- Keep the existing `<table>` layout for Histórico — do not redesign it into a card list. The original spec's card-style markup is adapted to a table row + status badge instead, to avoid an unrequested full-page redesign (see project memory: "the migration was deliberately superficial... don't read the current styling as a design system").
- "Future" applies to every `Transaction` row shown in Histórico, not just quick-entry ones — the predicate must not assume how the row was created.

---

### Task 1: Add `Transaction#future?`

**Files:**
- Modify: `app/models/transaction.rb`
- Test: `spec/models/transaction_spec.rb`

**Interfaces:**
- Produces: `Transaction#future? -> Boolean` — `true` when `date > Date.current`, `false` when `date <= Date.current`.

- [ ] **Step 1: Write the failing tests**

Add to `spec/models/transaction_spec.rb`, after the existing `#signed_amount` block:

```ruby
  describe "#future?" do
    it "is true for a transaction dated after today" do
      transaction = build(:transaction, date: Date.current + 5.days)
      expect(transaction.future?).to eq(true)
    end

    it "is false for a transaction dated today" do
      transaction = build(:transaction, date: Date.current)
      expect(transaction.future?).to eq(false)
    end

    it "is false for a transaction dated in the past" do
      transaction = build(:transaction, date: Date.current - 5.days)
      expect(transaction.future?).to eq(false)
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/models/transaction_spec.rb -e "#future?"`
Expected: FAIL — `NoMethodError: undefined method 'future?'`.

- [ ] **Step 3: Implement the predicate**

In `app/models/transaction.rb`, add the method after `signed_amount` (replace lines 11-14):

```ruby
  def signed_amount
    income? ? amount : -amount
  end

  def future?
    date > Date.current
  end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/models/transaction_spec.rb`
Expected: PASS — all examples green.

- [ ] **Step 5: Commit**

```bash
git add app/models/transaction.rb spec/models/transaction_spec.rb
git commit -m "feat: add Transaction#future? to distinguish realized from projected entries"
```

---

### Task 2: Style Histórico rows by realized/future status

**Files:**
- Modify: `app/views/dashboard/index.html.erb`
- Test: `spec/requests/dashboard_spec.rb`

**Interfaces:**
- Consumes: `Transaction#future?` (Task 1).

- [ ] **Step 1: Write the failing request spec**

Add to `spec/requests/dashboard_spec.rb`, inside the `RSpec.describe "Dashboard"` block:

```ruby
  it "marks a future-dated transaction as Previsto and a past one as Confirmado" do
    category = create(:category)
    create(:transaction, category: category, description: "Salário", amount: 3000, kind: :income, date: Date.current + 5.days)
    create(:transaction, category: category, description: "Mercado", amount: 100, kind: :expense, date: Date.current)

    get root_path, params: { month: "all" }

    expect(response.body).to include("Previsto")
    expect(response.body).to include("Confirmado")
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "marks a future-dated transaction"`
Expected: FAIL — neither "Previsto" nor "Confirmado" appear in the response body yet.

- [ ] **Step 3: Add the Status column and row styling**

In `app/views/dashboard/index.html.erb`, replace the Histórico `<table>` block (current lines 57-76, i.e. from `<h2 class="mb-2 mt-2 text-xl font-semibold">Histórico` through the closing `</table>`):

```erb
<h2 class="mb-2 mt-2 text-xl font-semibold">Histórico — <%= @selected_month_label %></h2>
<table class="w-full bg-white text-sm">
  <thead>
    <tr>
      <th class="border px-3 py-2 text-left">Data</th>
      <th class="border px-3 py-2 text-left">Descrição</th>
      <th class="border px-3 py-2 text-left">Categoria</th>
      <th class="border px-3 py-2 text-left">Status</th>
      <th class="border px-3 py-2 text-left">Valor</th>
    </tr>
  </thead>
  <tbody>
    <% @transactions.each do |transaction| %>
      <% row_bg = transaction.future? ? "bg-slate-50/70 opacity-80" : "bg-white" %>
      <% cell_border = transaction.future? ? "border border-dashed border-slate-300" : "border border-slate-200" %>
      <tr class="transaction-row transaction-row--<%= transaction.kind %> <%= row_bg %>">
        <td class="<%= cell_border %> px-3 py-2"><%= transaction.date.strftime("%d/%m/%Y") %></td>
        <td class="<%= cell_border %> px-3 py-2"><%= transaction.description %></td>
        <td class="<%= cell_border %> px-3 py-2"><%= transaction.category.name %></td>
        <td class="<%= cell_border %> px-3 py-2">
          <% if transaction.future? %>
            <span class="rounded-full border border-dashed border-slate-300 bg-slate-50 px-2 py-0.5 text-xs italic text-slate-500">Previsto</span>
          <% else %>
            <span class="rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-700">Confirmado</span>
          <% end %>
        </td>
        <td class="<%= cell_border %> px-3 py-2"><%= number_to_currency(transaction.amount, unit: "R$ ") %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

- [ ] **Step 4: Run the full dashboard request spec suite**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: PASS — new example passes; pre-existing examples still pass since they only check for description/currency substrings, which are unaffected by the added column.

- [ ] **Step 5: Commit**

```bash
git add app/views/dashboard/index.html.erb spec/requests/dashboard_spec.rb
git commit -m "feat: visually differentiate realized vs. future transactions in Histórico"
```

---

## Self-Review Notes

- **Spec coverage:** the "confirmed uses solid background/full opacity, future uses dashed border + translucent" requirement is covered directly; the icon/status-copy portion of the original mockup is expressed as a "Confirmado"/"Previsto" badge in a dedicated column rather than a free-floating caption, since this app's Histórico is a table, not a card list.
- **Deliberate deviation:** the original spec assumed a `transaction.paid?`/`.pending?` API that doesn't exist here — replaced with the derived `future?` predicate, which is the only concept this codebase actually supports (no status is ever persisted on a `Transaction`).
- **No placeholders:** every step has runnable code and exact file content.
