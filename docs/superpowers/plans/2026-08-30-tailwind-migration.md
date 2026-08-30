# Migração Bootstrap → Tailwind Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Bootstrap (CDN CSS only, no Bootstrap JS in use) and replace it with Tailwind CSS across all 17 `.erb` views, using the `tailwindcss-rails` gem.

**Architecture:** Pure markup/CSS migration — no Ruby logic changes, no new components/partials, no new database or business logic. Each task edits a fixed set of `.erb` files (and, in Task 1, `Gemfile`/`bin/dev`/`app/assets/stylesheets/application.css`), swapping Bootstrap classes for Tailwind utility classes using the mapping table below. Structural classes used by JS/CSS hooks (`quick-entry*`, `transaction-row--*`, `fixed-toggle`, `parcelado-toggle`) are preserved verbatim — only presentational classes change.

**Tech Stack:** Ruby on Rails 8.1, Propshaft, importmap-rails, `tailwindcss-rails` gem (Tailwind CLI, no Node build step), RSpec + Capybara.

## Global Constraints

- Ruby `4.0.6`, Rails `~> 8.1.3`. Asset pipeline is Propshaft (no Sprockets, no Node/esbuild).
- `bin/dev` is a hand-written Ruby script (not Procfile/foreman-based) that spawns `./bin/jobs` and `./bin/rails server`. It has no `Procfile.dev`, so the Tailwind watcher process must be added directly to `bin/dev`, following the same `Process.spawn` pattern already used there.
- This is a **visual-parity-free** migration per the approved spec (`docs/superpowers/specs/2026-08-30-tailwind-migration-design.md`): tables, cards, badges etc. get plain, functional Tailwind styling — no attempt to replicate Bootstrap's exact look (shadows, striping, rounded corners, spacing scale).
- No new Ruby logic, no new partials/components. Every step is a direct edit to an existing file.
- **Verification is regression-based, not TDD-red/green**: there is no unit-testable "is this the right CSS class." Existing RSpec request specs (`spec/requests/*_spec.rb`) already assert on page status/content, not on Bootstrap classes (verified during brainstorming — zero hits for `class=`/`assert_select`/`have_css` referencing Bootstrap class names). Each task's verification step is `bundle exec rspec`, run after the edits, to confirm no rendering regressions (missing partials, broken ERB, etc.).
- Class mapping used consistently across all tasks (Bootstrap → Tailwind):

  | Bootstrap | Tailwind replacement |
  |---|---|
  | `mb-3` (form field spacing) | `mb-4` |
  | `.form-label` | `mb-1 block text-sm font-medium text-gray-700` |
  | `.form-control` / `.form-select` | `w-full rounded border border-gray-300 px-3 py-2 text-sm` |
  | `.form-check` (wrapper) | `flex items-center gap-2 mb-4` |
  | `.form-check-input` | `h-4 w-4 rounded border-gray-300` |
  | `.form-check-label` | `text-sm text-gray-700` |
  | `.btn.btn-primary` | `rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700` |
  | `.btn.btn-outline-primary` | `rounded border border-blue-600 px-4 py-2 text-sm text-blue-600 hover:bg-blue-50` |
  | `.btn.btn-sm.btn-outline-secondary` | `rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50` |
  | `.btn.btn-sm.btn-outline-danger` | `rounded border border-red-300 px-2 py-1 text-xs text-red-600 hover:bg-red-50` |
  | `.btn.btn-danger` | `bg-red-600 hover:bg-red-700` (+ base button classes) |
  | `.btn.btn-success` | `bg-green-600 hover:bg-green-700` (+ base button classes) |
  | `.btn.btn-outline-light.btn-sm` | `rounded border border-gray-500 px-3 py-1 text-xs text-gray-200 hover:bg-gray-800` |
  | `.alert.alert-danger` | `rounded border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700` |
  | `.alert.alert-success` | `rounded border border-green-300 bg-green-50 px-4 py-3 text-sm text-green-700` |
  | `.badge.bg-danger` / `.bg-success` / `.bg-secondary` | `rounded-full px-2 py-1 text-xs font-medium text-white` + `bg-red-600` / `bg-green-600` / `bg-gray-500` |
  | `.table` cells | `border px-3 py-2` (`text-left` on `<th>`) on a `w-full bg-white text-sm` table — no striping/bordered variants |
  | `.text-success` / `.text-danger` | `text-green-600` / `text-red-600` |
  | `.text-end` | `text-right` |
  | `.fw-semibold` / `.fw-bold` | `font-semibold` / `font-bold` |
  | `h1`/`h2.h4` page headings | `text-2xl font-bold mb-4` (h1), `text-xl font-semibold mb-2 mt-2` (h2) |
  | `.container` (main) | `mx-auto max-w-5xl px-4` |
  | `.navbar.navbar-dark.bg-dark` | `bg-gray-900 text-white` |
  | `.nav-link` | `text-sm text-gray-200 hover:text-white` |
  | `.row`/`.col-*` (dashboard quick-entry grid) | `grid grid-cols-1 gap-4 md:grid-cols-2` |
  | `.row.g-2.align-items-end` (filter form) | `flex flex-wrap items-end gap-3` |
  | `.card`/`.card-header`/`.card-body` | `rounded border border-gray-200`, header: `px-4 py-2 text-lg font-bold`, body: `px-4 py-4` |
  | `body.bg-light` | `bg-gray-50 text-gray-900` |

---

### Task 1: Install Tailwind, remove Bootstrap

**Files:**
- Modify: `Gemfile`
- Modify: `bin/dev`
- Modify: `app/views/layouts/application.html.erb:21` (head only — CDN link and stylesheet tags)
- Modify: `app/assets/stylesheets/application.css`
- Test: `bundle exec rspec` (full suite, regression check)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `tailwindcss-rails` gem installed; `app/assets/tailwind/application.css` (Tailwind source, created by the installer) compiled to a `tailwind` asset referenced via `stylesheet_link_tag "tailwind"`; `bin/dev` now also runs the Tailwind watcher. All later tasks assume Tailwind utility classes are available and Bootstrap's CSS variables (`--bs-*`) no longer exist.

- [ ] **Step 1: Add the gem and install**

Add to `Gemfile`, in the assets group near `propshaft`/`importmap-rails`:

```ruby
# Tailwind CSS, compiled via the standalone CLI (no Node build step)
gem "tailwindcss-rails"
```

Run:

```bash
bundle install
```

- [ ] **Step 2: Run the Tailwind installer**

```bash
bin/rails tailwindcss:install
```

This creates `app/assets/tailwind/application.css` (the Tailwind source file) and wires up the `tailwindcss:build`/`tailwindcss:watch` rake tasks. Confirm the file was created:

```bash
test -f app/assets/tailwind/application.css && echo OK
```

- [ ] **Step 3: Add the Tailwind watcher to `bin/dev`**

Edit `bin/dev` to spawn the watcher alongside the existing processes:

```ruby
#!/usr/bin/env ruby
# Runs the Rails server together with the Solid Queue supervisor, so
# scheduled jobs (config/recurring.yml) actually execute while developing.
pids = [
  Process.spawn("./bin/jobs"),
  Process.spawn("./bin/rails", "tailwindcss:watch"),
  Process.spawn("./bin/rails", "server", *ARGV)
]

at_exit do
  pids.each { |pid| Process.kill("TERM", pid) rescue nil }
end

pids.each { |pid| Process.waitpid(pid) rescue nil }
```

- [ ] **Step 4: Remove the Bootstrap CDN link and add the Tailwind stylesheet tag**

In `app/views/layouts/application.html.erb`, replace this line:

```erb
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">

    <%# Includes all stylesheet files in app/assets/stylesheets %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

with:

```erb
    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>

    <%# Includes all stylesheet files in app/assets/stylesheets %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

- [ ] **Step 5: Replace Bootstrap CSS variables in the custom stylesheet**

Replace the full contents of `app/assets/stylesheets/application.css` with:

```css
/*
 * Local styles Tailwind's utility classes can't express: the JS-free field
 * toggles (Avulso/Fixo, Parcelado) built with the CSS :has() selector.
 */

/* Quick entry: Avulso vs Fixo */

.quick-entry-field--fixo {
  display: none;
}

.quick-entry:has(.fixed-toggle:checked) .quick-entry-field--fixo {
  display: block;
}

.quick-entry:has(.fixed-toggle:checked) .quick-entry-field--avulso {
  display: none;
}

/* Quick entry: Parcelado vs sem parcelas, nested inside the Fixo block above */

.quick-entry-subfield--parcelado {
  display: none;
}

.quick-entry:has(.parcelado-toggle:checked) .quick-entry-subfield--parcelado {
  display: block;
}

.quick-entry:has(.parcelado-toggle:checked) .quick-entry-subfield--sem-parcelas {
  display: none;
}

/* Quick entry cards: red for Gasto, green for Receita */

.quick-entry--expense .quick-entry-summary {
  background-color: #dc2626;
  color: #fff;
}

.quick-entry--income .quick-entry-summary {
  background-color: #16a34a;
  color: #fff;
}

.quick-entry-summary {
  cursor: pointer;
  list-style: none;
}

.quick-entry-summary::-webkit-details-marker {
  display: none;
}

/* History table: color the amount by kind */

.transaction-row--expense td:last-child {
  color: #dc2626;
  font-weight: 600;
}

.transaction-row--income td:last-child {
  color: #16a34a;
  font-weight: 600;
}
```

- [ ] **Step 6: Build Tailwind once and run the full test suite**

```bash
bin/rails tailwindcss:build
bundle exec rspec
```

Expected: build succeeds, full suite passes (no new failures vs. pre-migration baseline).

- [ ] **Step 7: Commit**

```bash
git add Gemfile Gemfile.lock bin/dev app/views/layouts/application.html.erb app/assets/stylesheets/application.css app/assets/tailwind config/initializers
git commit -m "chore: instalar tailwindcss-rails e remover Bootstrap CDN"
```

(Add any other files the installer generated, e.g. under `config/initializers` — check `git status` before committing.)

---

### Task 2: Migrate the layout shell (navbar, container, flash)

**Files:**
- Modify: `app/views/layouts/application.html.erb` (body only — head already migrated in Task 1)
- Test: `bundle exec rspec`

**Interfaces:**
- Consumes: Tailwind utilities available from Task 1.
- Produces: the persistent page chrome all other views render inside — later tasks don't touch this file.

- [ ] **Step 1: Replace the `<body>` content**

Replace everything from `<body class="bg-light">` to the closing `</html>` with:

```erb
  <body class="bg-gray-50 text-gray-900">
    <% if user_signed_in? %>
      <nav class="mb-6 bg-gray-900 text-white">
        <div class="mx-auto flex max-w-5xl flex-wrap items-center gap-4 px-4 py-3">
          <%= link_to "Gestão Financeira", root_path, class: "text-lg font-bold text-white" %>
          <div class="flex flex-1 flex-wrap gap-3">
            <%= link_to "Painel", root_path, class: "text-sm text-gray-200 hover:text-white" %>
            <%= link_to "Categorias", categories_path, class: "text-sm text-gray-200 hover:text-white" %>
            <%= link_to "Lançamentos", transactions_path, class: "text-sm text-gray-200 hover:text-white" %>
            <%= link_to "Recorrências", recurring_entries_path, class: "text-sm text-gray-200 hover:text-white" %>
          </div>
          <%= button_to "Sair", destroy_user_session_path, method: :delete, class: "rounded border border-gray-500 px-3 py-1 text-xs text-gray-200 hover:bg-gray-800" %>
        </div>
      </nav>
    <% end %>

    <main class="mx-auto max-w-5xl px-4 pb-12">
      <% flash.each do |type, message| %>
        <div class="mb-4 rounded border px-4 py-3 text-sm <%= type == "alert" ? "border-red-300 bg-red-50 text-red-700" : "border-green-300 bg-green-50 text-green-700" %>" role="alert">
          <%= message %>
        </div>
      <% end %>

      <%= yield %>
    </main>
  </body>
</html>
```

- [ ] **Step 2: Run the full test suite**

```bash
bundle exec rspec
```

Expected: passes (`spec/requests/sessions_spec.rb` and `spec/requests/dashboard_spec.rb` exercise this layout directly).

- [ ] **Step 3: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "refactor: migrar layout shell para Tailwind"
```

---

### Task 3: Migrate dashboard + quick entry form

**Files:**
- Modify: `app/views/dashboard/index.html.erb`
- Modify: `app/views/dashboard/_quick_entry_form.html.erb`
- Test: `bundle exec rspec`

**Interfaces:**
- Consumes: Tailwind utilities (Task 1), layout (Task 2).
- Produces: n/a — leaf views.

- [ ] **Step 1: Replace `app/views/dashboard/index.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Painel</h1>

<h2 class="mb-2 mt-2 text-xl font-semibold">Lançar</h2>
<div class="mb-6 grid grid-cols-1 gap-4 md:grid-cols-2">
  <%= render "dashboard/quick_entry_form", kind: "expense", label: "Gasto",
        categories: Category.expense.order(:name),
        record: (@quick_entry_kind == "expense" ? @quick_entry_record : nil) %>

  <%= render "dashboard/quick_entry_form", kind: "income", label: "Receita",
        categories: Category.income.order(:name),
        record: (@quick_entry_kind == "income" ? @quick_entry_record : nil) %>
</div>

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

<%= form_with url: root_path, method: :get, html: { class: "mb-6 flex flex-wrap items-end gap-3" } do %>
  <div>
    <%= label_tag :month, "Período (Resumo e Histórico)", class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= select_tag :month, options_for_select(@month_options, @selected_month), class: "rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div>
    <%= label_tag :category_id, "Categoria", class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= select_tag :category_id, options_for_select([ [ "Todas as categorias", "" ] ] + @category_options, @selected_category_id), class: "rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div>
    <%= submit_tag "Filtrar", class: "rounded border border-blue-600 px-4 py-2 text-sm text-blue-600 hover:bg-blue-50" %>
  </div>
<% end %>

<h2 class="mb-2 mt-2 text-xl font-semibold">Resumo — <%= @selected_month_label %></h2>
<table class="mb-6 w-full bg-white text-sm">
  <tbody>
    <tr>
      <td class="border px-3 py-2">Receitas</td>
      <td class="border px-3 py-2 font-semibold text-green-600"><%= number_to_currency(@month_income_total, unit: "R$ ") %></td>
    </tr>
    <tr>
      <td class="border px-3 py-2">Gastos</td>
      <td class="border px-3 py-2 font-semibold text-red-600"><%= number_to_currency(@month_expense_total, unit: "R$ ") %></td>
    </tr>
  </tbody>
</table>

<h2 class="mb-2 mt-2 text-xl font-semibold">Histórico — <%= @selected_month_label %></h2>
<table class="w-full bg-white text-sm">
  <thead>
    <tr>
      <th class="border px-3 py-2 text-left">Data</th>
      <th class="border px-3 py-2 text-left">Descrição</th>
      <th class="border px-3 py-2 text-left">Categoria</th>
      <th class="border px-3 py-2 text-left">Valor</th>
    </tr>
  </thead>
  <tbody>
    <% @transactions.each do |transaction| %>
      <tr class="transaction-row transaction-row--<%= transaction.kind %>">
        <td class="border px-3 py-2"><%= transaction.date.strftime("%d/%m/%Y") %></td>
        <td class="border px-3 py-2"><%= transaction.description %></td>
        <td class="border px-3 py-2"><%= transaction.category.name %></td>
        <td class="border px-3 py-2"><%= number_to_currency(transaction.amount, unit: "R$ ") %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

Note: `transaction-row transaction-row--<%= transaction.kind %>` is kept verbatim — `application.css` targets it for amount coloring.

- [ ] **Step 2: Replace `app/views/dashboard/_quick_entry_form.html.erb`**

```erb
<% is_recurring = record.is_a?(RecurringEntry)
   is_parcelado = is_recurring && record.installments.present? %>

<details<%= " open" if record&.errors&.any? %> class="quick-entry quick-entry--<%= kind %> rounded border border-gray-200">
  <summary class="quick-entry-summary rounded-t px-4 py-2 text-lg font-bold"><%= label %></summary>

  <div class="px-4 py-4">
    <%= form_with url: quick_entries_path, method: :post do %>
      <% if record&.errors&.any? %>
        <div class="mb-4 rounded border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700 error-messages">
          <ul>
            <% record.errors.full_messages.each do |message| %>
              <li><%= message %></li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <%= hidden_field_tag :kind, kind, id: "kind_#{kind}" %>

      <div class="mb-4">
        <%= label_tag "description_#{kind}", "Descrição", class: "mb-1 block text-sm font-medium text-gray-700" %>
        <%= text_field_tag :description, record&.description, id: "description_#{kind}", class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
      </div>

      <div class="mb-4">
        <%= label_tag "amount_#{kind}", "Valor", class: "mb-1 block text-sm font-medium text-gray-700" %>
        <%= number_field_tag :amount, record&.amount, step: 0.01, id: "amount_#{kind}", class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
      </div>

      <div class="mb-4">
        <%= label_tag "category_id_#{kind}", "Categoria", class: "mb-1 block text-sm font-medium text-gray-700" %>
        <%= select_tag :category_id, options_from_collection_for_select(categories, :id, :name, record&.category_id), id: "category_id_#{kind}", class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
      </div>

      <div class="mb-4 flex items-center gap-2">
        <%= check_box_tag :fixed, "1", record.is_a?(RecurringEntry), class: "h-4 w-4 rounded border-gray-300 fixed-toggle", id: "fixed_#{kind}" %>
        <%= label_tag "fixed_#{kind}", "Fixo (recorrente)", class: "text-sm text-gray-700" %>
      </div>

      <div class="mb-4 quick-entry-field quick-entry-field--avulso">
        <%= label_tag "date_#{kind}", "Data", class: "mb-1 block text-sm font-medium text-gray-700" %>
        <%= date_field_tag :date, (record.is_a?(Transaction) ? record.date : Date.current), id: "date_#{kind}", class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
      </div>

      <div class="quick-entry-field quick-entry-field--fixo">
        <div class="mb-4 flex items-center gap-2">
          <%= check_box_tag :parcelado, "1", is_parcelado, class: "h-4 w-4 rounded border-gray-300 parcelado-toggle", id: "parcelado_#{kind}" %>
          <%= label_tag "parcelado_#{kind}", "Parcelado?", class: "text-sm text-gray-700" %>
        </div>

        <div class="mb-4 quick-entry-subfield quick-entry-subfield--sem-parcelas">
          <%= label_tag "day_of_month_#{kind}", "Dia do mês", class: "mb-1 block text-sm font-medium text-gray-700" %>
          <%= number_field_tag :day_of_month, (is_recurring && !is_parcelado ? record.day_of_month : nil), min: 1, max: 31, id: "day_of_month_#{kind}", class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
        </div>

        <div class="quick-entry-subfield quick-entry-subfield--parcelado">
          <div class="mb-4">
            <%= label_tag "start_date_#{kind}", "Data de início", class: "mb-1 block text-sm font-medium text-gray-700" %>
            <%= date_field_tag :start_date, (is_parcelado ? record.start_date : Date.current), id: "start_date_#{kind}", class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
          </div>
          <div class="mb-4">
            <%= label_tag "installments_#{kind}", "Número de parcelas", class: "mb-1 block text-sm font-medium text-gray-700" %>
            <%= number_field_tag :installments, (is_parcelado ? record.installments : nil), min: 1, id: "installments_#{kind}", class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
          </div>
        </div>
      </div>

      <%= submit_tag label, class: "rounded px-4 py-2 text-sm font-medium text-white #{kind == 'expense' ? 'bg-red-600 hover:bg-red-700' : 'bg-green-600 hover:bg-green-700'}" %>
    <% end %>
  </div>
</details>
```

Note: `quick-entry`, `quick-entry--<kind>`, `quick-entry-summary`, `quick-entry-field*`, `quick-entry-subfield*`, `fixed-toggle`, `parcelado-toggle` are all kept verbatim — `application.css`'s `:has()` toggles and color rules depend on them. The old `<div class="col-md-6">` wrapper is dropped since `index.html.erb`'s grid now sizes the two rendered partials directly.

- [ ] **Step 3: Run the full test suite**

```bash
bundle exec rspec
```

Expected: passes (`spec/requests/dashboard_spec.rb`, `spec/requests/quick_entries_spec.rb` cover this).

- [ ] **Step 4: Commit**

```bash
git add app/views/dashboard/index.html.erb app/views/dashboard/_quick_entry_form.html.erb
git commit -m "refactor: migrar dashboard e quick entry form para Tailwind"
```

---

### Task 4: Migrate transactions views

**Files:**
- Modify: `app/views/transactions/_form.html.erb`
- Modify: `app/views/transactions/index.html.erb`
- Modify: `app/views/transactions/new.html.erb`
- Modify: `app/views/transactions/edit.html.erb`
- Test: `bundle exec rspec`

**Interfaces:**
- Consumes: Tailwind utilities (Task 1), layout (Task 2).
- Produces: n/a — leaf views.

- [ ] **Step 1: Replace `app/views/transactions/_form.html.erb`**

```erb
<%= form_with model: transaction do |f| %>
  <div class="mb-4">
    <%= f.label :description, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.text_field :description, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4">
    <%= f.label :amount, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.number_field :amount, step: 0.01, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4">
    <%= f.label :kind, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.select :kind, Transaction.kinds.keys, {}, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4">
    <%= f.label :date, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.date_field :date, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4">
    <%= f.label :category_id, "Categoria", class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.collection_select :category_id, Category.order(:name), :id, :name, {}, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <%= f.submit class: "rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
<% end %>
```

- [ ] **Step 2: Replace `app/views/transactions/index.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Lançamentos</h1>
<%= link_to "Novo lançamento", new_transaction_path, class: "mb-4 inline-block rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>

<table class="w-full bg-white text-sm">
  <thead>
    <tr>
      <th class="border px-3 py-2 text-left">Data</th>
      <th class="border px-3 py-2 text-left">Descrição</th>
      <th class="border px-3 py-2 text-left">Tipo</th>
      <th class="border px-3 py-2 text-left">Valor</th>
      <th class="border px-3 py-2 text-left">Categoria</th>
      <th class="border px-3 py-2 text-left"></th>
    </tr>
  </thead>
  <tbody>
    <% @transactions.each do |transaction| %>
      <tr>
        <td class="border px-3 py-2"><%= transaction.date.strftime("%d/%m/%Y") %></td>
        <td class="border px-3 py-2"><%= transaction.description %></td>
        <td class="border px-3 py-2">
          <span class="rounded-full px-2 py-1 text-xs font-medium text-white <%= transaction.expense? ? 'bg-red-600' : 'bg-green-600' %>">
            <%= transaction.expense? ? "Gasto" : "Receita" %>
          </span>
        </td>
        <td class="border px-3 py-2 font-semibold <%= transaction.expense? ? 'text-red-600' : 'text-green-600' %>">
          <%= number_to_currency(transaction.amount, unit: "R$ ") %>
        </td>
        <td class="border px-3 py-2"><%= transaction.category.name %></td>
        <td class="border px-3 py-2 text-right">
          <%= link_to "Editar", edit_transaction_path(transaction), class: "rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50" %>
          <%= link_to "Remover", transaction_path(transaction), data: { turbo_method: :delete, turbo_confirm: "Tem certeza?" }, class: "rounded border border-red-300 px-2 py-1 text-xs text-red-600 hover:bg-red-50" %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

- [ ] **Step 3: Replace `app/views/transactions/new.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Novo lançamento</h1>
<%= render "form", transaction: @transaction %>
```

- [ ] **Step 4: Replace `app/views/transactions/edit.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Editar lançamento</h1>
<%= render "form", transaction: @transaction %>
```

- [ ] **Step 5: Run the full test suite**

```bash
bundle exec rspec
```

Expected: passes (`spec/requests/transactions_spec.rb` covers CRUD on these views).

- [ ] **Step 6: Commit**

```bash
git add app/views/transactions
git commit -m "refactor: migrar views de transactions para Tailwind"
```

---

### Task 5: Migrate recurring_entries views

**Files:**
- Modify: `app/views/recurring_entries/_form.html.erb`
- Modify: `app/views/recurring_entries/index.html.erb`
- Modify: `app/views/recurring_entries/new.html.erb`
- Modify: `app/views/recurring_entries/edit.html.erb`
- Test: `bundle exec rspec`

**Interfaces:**
- Consumes: Tailwind utilities (Task 1), layout (Task 2).
- Produces: n/a — leaf views.

- [ ] **Step 1: Replace `app/views/recurring_entries/_form.html.erb`**

```erb
<%= form_with model: recurring_entry do |f| %>
  <div class="mb-4">
    <%= f.label :description, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.text_field :description, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4">
    <%= f.label :amount, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.number_field :amount, step: 0.01, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4">
    <%= f.label :kind, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.select :kind, RecurringEntry.kinds.keys, {}, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4">
    <%= f.label :day_of_month, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.number_field :day_of_month, min: 1, max: 31, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4 flex items-center gap-2">
    <%= f.check_box :active, class: "h-4 w-4 rounded border-gray-300" %>
    <%= f.label :active, class: "text-sm text-gray-700" %>
  </div>
  <div class="mb-4">
    <%= f.label :start_date, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.date_field :start_date, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4">
    <%= f.label :installments, "Número de parcelas (deixe em branco pra recorrência sem fim)", class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.number_field :installments, min: 1, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4">
    <%= f.label :category_id, "Categoria", class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.collection_select :category_id, Category.order(:name), :id, :name, {}, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <%= f.submit class: "rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
<% end %>
```

- [ ] **Step 2: Replace `app/views/recurring_entries/index.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Gastos e receitas fixas</h1>
<%= link_to "Nova recorrência", new_recurring_entry_path, class: "mb-4 inline-block rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>

<table class="w-full bg-white text-sm">
  <thead>
    <tr>
      <th class="border px-3 py-2 text-left">Descrição</th>
      <th class="border px-3 py-2 text-left">Dia</th>
      <th class="border px-3 py-2 text-left">Tipo</th>
      <th class="border px-3 py-2 text-left">Valor</th>
      <th class="border px-3 py-2 text-left">Categoria</th>
      <th class="border px-3 py-2 text-left">Status</th>
      <th class="border px-3 py-2 text-left">Até</th>
      <th class="border px-3 py-2 text-left"></th>
    </tr>
  </thead>
  <tbody>
    <% @recurring_entries.each do |entry| %>
      <tr>
        <td class="border px-3 py-2"><%= entry.description %></td>
        <td class="border px-3 py-2"><%= entry.day_of_month %></td>
        <td class="border px-3 py-2">
          <span class="rounded-full px-2 py-1 text-xs font-medium text-white <%= entry.expense? ? 'bg-red-600' : 'bg-green-600' %>">
            <%= entry.expense? ? "Gasto" : "Receita" %>
          </span>
        </td>
        <td class="border px-3 py-2 font-semibold <%= entry.expense? ? 'text-red-600' : 'text-green-600' %>">
          <%= number_to_currency(entry.amount, unit: "R$ ") %>
        </td>
        <td class="border px-3 py-2"><%= entry.category.name %></td>
        <td class="border px-3 py-2">
          <span class="rounded-full px-2 py-1 text-xs font-medium text-white <%= entry.active? ? 'bg-green-600' : 'bg-gray-500' %>">
            <%= entry.active? ? "Ativa" : "Inativa" %>
          </span>
        </td>
        <td class="border px-3 py-2"><%= entry.end_date ? entry.end_date.strftime("%d/%m/%Y") : "Sem fim" %></td>
        <td class="border px-3 py-2 text-right">
          <%= link_to "Editar", edit_recurring_entry_path(entry), class: "rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50" %>
          <%= link_to "Remover", recurring_entry_path(entry), data: { turbo_method: :delete, turbo_confirm: "Tem certeza?" }, class: "rounded border border-red-300 px-2 py-1 text-xs text-red-600 hover:bg-red-50" %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

- [ ] **Step 3: Replace `app/views/recurring_entries/new.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Nova recorrência</h1>
<%= render "form", recurring_entry: @recurring_entry %>
```

- [ ] **Step 4: Replace `app/views/recurring_entries/edit.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Editar recorrência</h1>
<%= render "form", recurring_entry: @recurring_entry %>
```

- [ ] **Step 5: Run the full test suite**

```bash
bundle exec rspec
```

Expected: passes (`spec/requests/recurring_entries_spec.rb` covers CRUD on these views).

- [ ] **Step 6: Commit**

```bash
git add app/views/recurring_entries
git commit -m "refactor: migrar views de recurring_entries para Tailwind"
```

---

### Task 6: Migrate categories views

**Files:**
- Modify: `app/views/categories/_form.html.erb`
- Modify: `app/views/categories/index.html.erb`
- Modify: `app/views/categories/new.html.erb`
- Modify: `app/views/categories/edit.html.erb`
- Test: `bundle exec rspec`

**Interfaces:**
- Consumes: Tailwind utilities (Task 1), layout (Task 2).
- Produces: n/a — leaf views.

- [ ] **Step 1: Replace `app/views/categories/_form.html.erb`**

```erb
<%= form_with model: category do |f| %>
  <div class="mb-4">
    <%= f.label :name, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.text_field :name, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <div class="mb-4">
    <%= f.label :kind, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.select :kind, Category.kinds.keys, {}, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>
  <%= f.submit class: "rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
<% end %>
```

- [ ] **Step 2: Replace `app/views/categories/index.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Categorias</h1>
<%= link_to "Nova categoria", new_category_path, class: "mb-4 inline-block rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>

<table class="w-full bg-white text-sm">
  <thead>
    <tr>
      <th class="border px-3 py-2 text-left">Nome</th>
      <th class="border px-3 py-2 text-left">Tipo</th>
      <th class="border px-3 py-2 text-left"></th>
    </tr>
  </thead>
  <tbody>
    <% @categories.each do |category| %>
      <tr>
        <td class="border px-3 py-2"><%= link_to category.name, category_path(category) %></td>
        <td class="border px-3 py-2">
          <span class="rounded-full px-2 py-1 text-xs font-medium text-white <%= category.expense? ? 'bg-red-600' : 'bg-green-600' %>">
            <%= category.expense? ? "Gasto" : "Receita" %>
          </span>
        </td>
        <td class="border px-3 py-2 text-right">
          <%= link_to "Editar", edit_category_path(category), class: "rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50" %>
          <%= link_to "Remover", category_path(category), data: { turbo_method: :delete, turbo_confirm: "Tem certeza?" }, class: "rounded border border-red-300 px-2 py-1 text-xs text-red-600 hover:bg-red-50" %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

- [ ] **Step 3: Replace `app/views/categories/new.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Nova categoria</h1>
<%= render "form", category: @category %>
```

- [ ] **Step 4: Replace `app/views/categories/edit.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Editar categoria</h1>
<%= render "form", category: @category %>
```

- [ ] **Step 5: Run the full test suite**

```bash
bundle exec rspec
```

Expected: passes (`spec/requests/categories_spec.rb` covers CRUD on these views).

- [ ] **Step 6: Commit**

```bash
git add app/views/categories
git commit -m "refactor: migrar views de categories para Tailwind"
```

---

### Task 7: Migrate devise login and account setup

**Files:**
- Modify: `app/views/devise/sessions/new.html.erb`
- Modify: `app/views/setup/new.html.erb`
- Test: `bundle exec rspec`

**Interfaces:**
- Consumes: Tailwind utilities (Task 1), layout (Task 2).
- Produces: n/a — leaf views.

- [ ] **Step 1: Replace `app/views/devise/sessions/new.html.erb`**

```erb
<h2 class="mb-4 text-xl font-semibold">Log in</h2>

<%= form_for(resource, as: resource_name, url: session_path(resource_name)) do |f| %>
  <div class="mb-4">
    <%= f.label :email, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.email_field :email, autofocus: true, autocomplete: "email", class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>

  <div class="mb-4">
    <%= f.label :password, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.password_field :password, autocomplete: "current-password", class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>

  <div class="mb-4">
    <%= f.submit "Log in", class: "rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
  </div>
<% end %>

<%= render "devise/shared/links" %>

<% if User.count.zero? %>
  <p><%= link_to "Criar conta", new_setup_path %></p>
<% end %>
```

- [ ] **Step 2: Replace `app/views/setup/new.html.erb`**

```erb
<h1 class="mb-4 text-2xl font-bold">Criar conta</h1>

<%= form_with model: @user, url: setup_path do |f| %>
  <% if @user.errors.any? %>
    <div class="mb-4 rounded border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700 error-messages">
      <ul>
        <% @user.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="mb-4">
    <%= f.label :email, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.email_field :email, autofocus: true, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>

  <div class="mb-4">
    <%= f.label :password, class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.password_field :password, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>

  <div class="mb-4">
    <%= f.label :password_confirmation, "Confirmação de senha", class: "mb-1 block text-sm font-medium text-gray-700" %>
    <%= f.password_field :password_confirmation, class: "w-full rounded border border-gray-300 px-3 py-2 text-sm" %>
  </div>

  <%= f.submit "Criar conta", class: "rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
<% end %>
```

- [ ] **Step 3: Run the full test suite**

```bash
bundle exec rspec
```

Expected: passes (`spec/requests/sessions_spec.rb`, `spec/requests/setup_spec.rb` cover these views).

- [ ] **Step 4: Commit**

```bash
git add app/views/devise app/views/setup
git commit -m "refactor: migrar login e setup de conta para Tailwind"
```

---

### Task 8: Final sweep and verification

**Files:**
- None expected (verification-only), unless the grep in Step 1 finds a leftover.
- Test: `bundle exec rspec`

**Interfaces:**
- Consumes: all previous tasks.
- Produces: migration complete — Bootstrap fully removed.

- [ ] **Step 1: Grep for any leftover Bootstrap references**

```bash
grep -rnE 'class="[^"]*\b(btn|card|navbar|badge|alert|table-striped|table-bordered|form-control|form-select|form-check|form-label|form-group|container|row|col-[a-z0-9-]*|fw-[a-z]+|text-end)\b' app/views
grep -rn "bootstrap" app/views app/assets
```

Expected: no output. If something turns up, fix it using the mapping table in Global Constraints, then re-run the grep.

- [ ] **Step 2: Confirm the Bootstrap gem/CDN reference is gone from the whole repo**

```bash
grep -rn "bootstrap" --include="*.erb" --include="*.rb" --include="Gemfile" .
```

Expected: no output (or only unrelated matches, e.g. a comment/gem unrelated to Twitter Bootstrap — inspect any hit before treating it as expected).

- [ ] **Step 3: Run the full test suite one last time**

```bash
bundle exec rspec
```

Expected: full suite passes.

- [ ] **Step 4: Commit (only if Step 1 required fixes)**

```bash
git add -A
git commit -m "fix: remover últimas referências ao Bootstrap"
```
