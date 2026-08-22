# Gestão Financeira MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the initial version of a personal finance management Rails app: accounts, categories, one-off and recurring transactions, automatic monthly generation of fixed entries, and a dashboard with current + projected cash balance.

**Architecture:** Server-rendered Rails 8 monolith (Hotwire default, no API/SPA split), PostgreSQL, Devise for single-user auth with custom password complexity, Solid Queue for the recurring-transaction generation job.

**Tech Stack:** Ruby on Rails 8.x, PostgreSQL, Devise, Solid Queue, RSpec + FactoryBot + Capybara.

## Global Constraints

- Rails 8.x, server-rendered with Hotwire — no separate API/SPA.
- PostgreSQL only, monetary columns are `decimal` (never `float`).
- Single user, no public signup — user created via `db/seeds.rb`.
- Devise password validation must additionally require at least one uppercase letter and one special character (beyond Devise's default length check).
- Credit cards are modeled as a plain `Account` type — no invoice/closing-date logic in this version.
- All non-Devise controllers require `authenticate_user!`.
- Tests via RSpec; every task ships with passing tests before moving on.

---

### Task 1: Rails app scaffold + test tooling

**Files:**
- Create: entire Rails app skeleton at repo root (`Gemfile`, `app/`, `config/`, `bin/`, etc.) via `rails new`
- Modify: `Gemfile` — add `devise`; add `rspec-rails`, `factory_bot_rails`, `capybara`, `selenium-webdriver` to `:test` group
- Create: `spec/rails_helper.rb`, `spec/spec_helper.rb` (via `rspec:install` generator)
- Modify: `config/database.yml` — Postgres, databases `gestao_financeira_development` / `gestao_financeira_test`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: a booting Rails 8 app with RSpec wired up (`bundle exec rspec` runs, 0 examples), Postgres dev/test databases created. All later tasks build on this.

- [ ] **Step 1: Generate the Rails app**

```bash
rails new . --database=postgresql --skip-test
```

Answer "yes" if asked to overwrite (it should not conflict with the existing `docs/` directory or `.git`).

- [ ] **Step 2: Add gems**

Edit `Gemfile`, add near the top-level gems:

```ruby
gem "devise"
```

And inside the existing `group :test do ... end` block (create it if `--skip-test` didn't leave one):

```ruby
group :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "capybara"
  gem "selenium-webdriver"
end
```

- [ ] **Step 3: Install and configure RSpec**

```bash
bundle install
bundle exec rails generate rspec:install
```

Edit `spec/rails_helper.rb`, inside the `RSpec.configure do |config|` block, add:

```ruby
  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request
```

- [ ] **Step 4: Configure Postgres databases**

Edit `config/database.yml` so `development` and `test` use:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: gestao_financeira_development

test:
  <<: *default
  database: gestao_financeira_test
```

```bash
bin/rails db:create
```

- [ ] **Step 5: Verify the app boots and the test suite runs**

```bash
bundle exec rspec
```

Expected: `0 examples, 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Scaffold Rails app with RSpec, FactoryBot, Capybara, Postgres"
```

---

### Task 2: Devise authentication + password complexity + seed user

**Files:**
- Create: `config/initializers/devise.rb` (via generator)
- Create: `app/models/user.rb` (via generator, then edited)
- Create: `db/migrate/xxxx_devise_create_users.rb` (via generator)
- Modify: `config/routes.rb`
- Modify: `app/controllers/application_controller.rb`
- Create: `db/seeds.rb`
- Create: `spec/factories/users.rb`
- Test: `spec/models/user_spec.rb`

**Interfaces:**
- Consumes: booted app from Task 1.
- Produces: `User` model with Devise `:database_authenticatable, :recoverable, :validatable`; `ApplicationController` with `before_action :authenticate_user!` (every later controller inherits this); `db/seeds.rb` creating the single user from `ENV["SEED_USER_EMAIL"]` / `ENV["SEED_USER_PASSWORD"]`.

- [ ] **Step 1: Install Devise and generate the User model**

```bash
bundle exec rails generate devise:install
bundle exec rails generate devise User
bin/rails db:migrate
```

- [ ] **Step 2: Write the failing test for password complexity**

Create `spec/factories/users.rb`:

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Strong#Pass1" }
    password_confirmation { "Strong#Pass1" }
  end
end
```

Create `spec/models/user_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with an uppercase letter and a special character" do
    user = build(:user, password: "Strong#Pass1", password_confirmation: "Strong#Pass1")
    expect(user).to be_valid
  end

  it "is invalid without an uppercase letter" do
    user = build(:user, password: "weak#pass1", password_confirmation: "weak#pass1")
    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  it "is invalid without a special character" do
    user = build(:user, password: "WeakPass1", password_confirmation: "WeakPass1")
    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end
end
```

- [ ] **Step 2b: Run the test to verify it fails**

```bash
bundle exec rspec spec/models/user_spec.rb
```

Expected: the "invalid without an uppercase letter" and "invalid without a special character" examples FAIL (Devise's default validation only checks length, so these currently pass validation).

- [ ] **Step 3: Add the password complexity validation**

Edit `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :validatable

  validate :password_complexity

  private

  def password_complexity
    return if password.blank?

    unless password.match?(/\A(?=.*[A-Z])(?=.*[^A-Za-z0-9]).+\z/)
      errors.add(:password, "deve conter ao menos uma letra maiúscula e um caractere especial")
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
bundle exec rspec spec/models/user_spec.rb
```

Expected: `3 examples, 0 failures`.

- [ ] **Step 5: Require authentication globally**

Edit `app/controllers/application_controller.rb`:

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
end
```

- [ ] **Step 6: Add `devise_for :users` to routes**

Edit `config/routes.rb`, add inside `Rails.application.routes.draw do`:

```ruby
  devise_for :users
```

- [ ] **Step 7: Create the seed script**

Create `db/seeds.rb`:

```ruby
email = ENV.fetch("SEED_USER_EMAIL")
password = ENV.fetch("SEED_USER_PASSWORD")

User.find_or_create_by!(email: email) do |user|
  user.password = password
  user.password_confirmation = password
end
```

- [ ] **Step 8: Run the full suite**

```bash
bundle exec rspec
```

Expected: all examples pass.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "Add Devise authentication with password complexity and seed user"
```

---

### Task 3: Account model + CRUD

**Files:**
- Create: `db/migrate/xxxx_create_accounts.rb`
- Create: `app/models/account.rb`
- Create: `app/controllers/accounts_controller.rb`
- Create: `app/views/accounts/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`, `show.html.erb`
- Modify: `config/routes.rb`
- Create: `spec/factories/accounts.rb`
- Test: `spec/models/account_spec.rb`, `spec/requests/accounts_spec.rb`

**Interfaces:**
- Consumes: authenticated `ApplicationController` from Task 2.
- Produces: `Account` model — `name:string`, `account_type:integer` (enum `checking/savings/credit_card/cash`), `initial_balance:decimal`; `accounts` RESTful routes; used by Tasks 5, 6, 9, 10. No `has_many :transactions`/`has_many :recurring_entries` yet (added in Tasks 5/6).

- [ ] **Step 1: Write the failing model test**

Create `spec/factories/accounts.rb`:

```ruby
FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Conta #{n}" }
    account_type { :checking }
    initial_balance { 1000.0 }
  end
end
```

Create `spec/models/account_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Account, type: :model do
  it "is valid with a name, account_type and initial_balance" do
    expect(build(:account)).to be_valid
  end

  it "is invalid without a name" do
    expect(build(:account, name: nil)).not_to be_valid
  end

  it "exposes the expected account types" do
    expect(Account.account_types.keys).to contain_exactly("checking", "savings", "credit_card", "cash")
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/models/account_spec.rb
```

Expected: FAIL — `uninitialized constant Account`.

- [ ] **Step 3: Create the migration and model**

```bash
bundle exec rails generate migration CreateAccounts
```

Edit the generated migration file:

```ruby
class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.integer :account_type, null: false, default: 0
      t.decimal :initial_balance, precision: 12, scale: 2, null: false, default: 0

      t.timestamps
    end
  end
end
```

```bash
bin/rails db:migrate
```

Create `app/models/account.rb`:

```ruby
class Account < ApplicationRecord
  enum :account_type, { checking: 0, savings: 1, credit_card: 2, cash: 3 }

  validates :name, presence: true
  validates :account_type, presence: true
  validates :initial_balance, numericality: true
end
```

Note: no `has_many :transactions` / `has_many :recurring_entries` yet — those models don't exist until Tasks 5 and 6, which add the associations to this file when they create them. Do not create stub `Transaction`/`RecurringEntry` models or migrations to satisfy a forward reference; there is none in this version of the task.

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/models/account_spec.rb
```

Expected: `3 examples, 0 failures`.

- [ ] **Step 5: Add routes and controller**

Edit `config/routes.rb`:

```ruby
  resources :accounts
```

Create `app/controllers/accounts_controller.rb`:

```ruby
class AccountsController < ApplicationController
  before_action :set_account, only: %i[show edit update destroy]

  def index
    @accounts = Account.order(:name)
  end

  def show; end

  def new
    @account = Account.new
  end

  def edit; end

  def create
    @account = Account.new(account_params)
    if @account.save
      redirect_to accounts_path, notice: "Conta criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "Conta atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @account.destroy
    redirect_to accounts_path, notice: "Conta removida."
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :account_type, :initial_balance)
  end
end
```

- [ ] **Step 6: Add views**

Create `app/views/accounts/_form.html.erb`:

```erb
<%= form_with model: account do |f| %>
  <div>
    <%= f.label :name %>
    <%= f.text_field :name %>
  </div>
  <div>
    <%= f.label :account_type %>
    <%= f.select :account_type, Account.account_types.keys %>
  </div>
  <div>
    <%= f.label :initial_balance %>
    <%= f.number_field :initial_balance, step: 0.01 %>
  </div>
  <%= f.submit %>
<% end %>
```

Create `app/views/accounts/index.html.erb`:

```erb
<h1>Contas</h1>
<%= link_to "Nova conta", new_account_path %>
<ul>
  <% @accounts.each do |account| %>
    <li>
      <%= link_to account.name, account_path(account) %> (<%= account.account_type %>) —
      <%= link_to "Editar", edit_account_path(account) %> —
      <%= link_to "Remover", account_path(account), data: { turbo_method: :delete, turbo_confirm: "Tem certeza?" } %>
    </li>
  <% end %>
</ul>
```

Create `app/views/accounts/new.html.erb`:

```erb
<h1>Nova conta</h1>
<%= render "form", account: @account %>
```

Create `app/views/accounts/edit.html.erb`:

```erb
<h1>Editar conta</h1>
<%= render "form", account: @account %>
```

Create `app/views/accounts/show.html.erb`:

```erb
<h1><%= @account.name %></h1>
<p>Tipo: <%= @account.account_type %></p>
<p>Saldo inicial: <%= @account.initial_balance %></p>
<%= link_to "Voltar", accounts_path %>
```

- [ ] **Step 7: Write the failing request spec**

Create `spec/requests/accounts_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Accounts", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "creates an account" do
    expect {
      post accounts_path, params: { account: { name: "Nubank", account_type: "checking", initial_balance: 100 } }
    }.to change(Account, :count).by(1)
    expect(response).to redirect_to(accounts_path)
  end

  it "does not create an account without a name" do
    expect {
      post accounts_path, params: { account: { name: "", account_type: "checking", initial_balance: 100 } }
    }.not_to change(Account, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates an account" do
    account = create(:account)
    patch account_path(account), params: { account: { name: "Novo nome" } }
    expect(account.reload.name).to eq("Novo nome")
  end

  it "destroys an account" do
    account = create(:account)
    expect { delete account_path(account) }.to change(Account, :count).by(-1)
  end
end
```

- [ ] **Step 8: Run to verify it passes**

```bash
bundle exec rspec spec/requests/accounts_spec.rb
```

Expected: `4 examples, 0 failures`.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "Add Account model and CRUD"
```

---

### Task 4: Category model + CRUD

**Files:**
- Create: `db/migrate/xxxx_create_categories.rb`
- Create: `app/models/category.rb`
- Create: `app/controllers/categories_controller.rb`
- Create: `app/views/categories/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`, `show.html.erb`
- Modify: `config/routes.rb`
- Create: `spec/factories/categories.rb`
- Test: `spec/models/category_spec.rb`, `spec/requests/categories_spec.rb`

**Interfaces:**
- Consumes: authenticated `ApplicationController` from Task 2.
- Produces: `Category` model — `name:string`, `kind:integer` (enum `expense/income`), `color:string`; `categories` RESTful routes; used by Tasks 5, 6. No `has_many :transactions`/`has_many :recurring_entries` yet (added in Tasks 5/6).

- [ ] **Step 1: Write the failing model test**

Create `spec/factories/categories.rb`:

```ruby
FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Categoria #{n}" }
    kind { :expense }
  end
end
```

Create `spec/models/category_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Category, type: :model do
  it "is valid with a name and kind" do
    expect(build(:category)).to be_valid
  end

  it "is invalid without a name" do
    expect(build(:category, name: nil)).not_to be_valid
  end

  it "exposes expense and income kinds" do
    expect(Category.kinds.keys).to contain_exactly("expense", "income")
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/models/category_spec.rb
```

Expected: FAIL — `uninitialized constant Category`.

- [ ] **Step 3: Create the migration and model**

```bash
bundle exec rails generate migration CreateCategories
```

Edit the migration:

```ruby
class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.integer :kind, null: false, default: 0
      t.string :color

      t.timestamps
    end
  end
end
```

```bash
bin/rails db:migrate
```

Create `app/models/category.rb`:

```ruby
class Category < ApplicationRecord
  enum :kind, { expense: 0, income: 1 }

  validates :name, presence: true
  validates :kind, presence: true
end
```

Note: no `has_many :transactions` / `has_many :recurring_entries` yet — those models don't exist until Tasks 5 and 6, which add the associations to this file when they create them. Do not create stub `Transaction`/`RecurringEntry` models or migrations to satisfy a forward reference; there is none in this version of the task.

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/models/category_spec.rb
```

Expected: `3 examples, 0 failures`.

- [ ] **Step 5: Add routes, controller and views**

Edit `config/routes.rb`:

```ruby
  resources :categories
```

Create `app/controllers/categories_controller.rb`:

```ruby
class CategoriesController < ApplicationController
  before_action :set_category, only: %i[show edit update destroy]

  def index
    @categories = Category.order(:name)
  end

  def show; end

  def new
    @category = Category.new
  end

  def edit; end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to categories_path, notice: "Categoria criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: "Categoria atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to categories_path, notice: "Categoria removida."
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :kind, :color)
  end
end
```

Create `app/views/categories/_form.html.erb`:

```erb
<%= form_with model: category do |f| %>
  <div>
    <%= f.label :name %>
    <%= f.text_field :name %>
  </div>
  <div>
    <%= f.label :kind %>
    <%= f.select :kind, Category.kinds.keys %>
  </div>
  <div>
    <%= f.label :color %>
    <%= f.text_field :color %>
  </div>
  <%= f.submit %>
<% end %>
```

Create `app/views/categories/index.html.erb`:

```erb
<h1>Categorias</h1>
<%= link_to "Nova categoria", new_category_path %>
<ul>
  <% @categories.each do |category| %>
    <li>
      <%= link_to category.name, category_path(category) %> (<%= category.kind %>) —
      <%= link_to "Editar", edit_category_path(category) %> —
      <%= link_to "Remover", category_path(category), data: { turbo_method: :delete, turbo_confirm: "Tem certeza?" } %>
    </li>
  <% end %>
</ul>
```

Create `app/views/categories/new.html.erb`:

```erb
<h1>Nova categoria</h1>
<%= render "form", category: @category %>
```

Create `app/views/categories/edit.html.erb`:

```erb
<h1>Editar categoria</h1>
<%= render "form", category: @category %>
```

Create `app/views/categories/show.html.erb`:

```erb
<h1><%= @category.name %></h1>
<p>Tipo: <%= @category.kind %></p>
<%= link_to "Voltar", categories_path %>
```

- [ ] **Step 6: Write the failing request spec**

Create `spec/requests/categories_spec.rb`:

```ruby
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
end
```

- [ ] **Step 7: Run to verify it passes**

```bash
bundle exec rspec spec/requests/categories_spec.rb
```

Expected: `4 examples, 0 failures`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Add Category model and CRUD"
```

---

### Task 5: Transaction model + CRUD

**Files:**
- Create: `db/migrate/xxxx_create_transactions.rb`
- Create: `app/models/transaction.rb`
- Create: `app/controllers/transactions_controller.rb`
- Create: `app/views/transactions/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`, `show.html.erb`
- Modify: `config/routes.rb`
- Create: `spec/factories/transactions.rb`
- Test: `spec/models/transaction_spec.rb`, `spec/requests/transactions_spec.rb`

**Interfaces:**
- Consumes: `Account` (Task 3), `Category` (Task 4).
- Produces: `Transaction` model — `description:string`, `amount:decimal`, `kind:integer` (enum `expense/income`), `date:date`, `belongs_to :account`, `belongs_to :category`; `Transaction#signed_amount` (income → `+amount`, expense → `-amount`); `transactions` RESTful routes. Used by Tasks 7, 9, 10. No `recurring_entry_id` column or `belongs_to :recurring_entry` yet (added in Task 6, alongside `RecurringEntry` itself).

- [ ] **Step 1: Write the failing model test**

Create `spec/factories/transactions.rb`:

```ruby
FactoryBot.define do
  factory :transaction do
    description { "Compra no mercado" }
    amount { 150.50 }
    kind { :expense }
    date { Date.current }
    account
    category
  end
end
```

Create `spec/models/transaction_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Transaction, type: :model do
  it "is valid with description, amount, kind, date, account and category" do
    expect(build(:transaction)).to be_valid
  end

  it "is invalid without a description" do
    expect(build(:transaction, description: nil)).not_to be_valid
  end

  it "is invalid with a zero amount" do
    expect(build(:transaction, amount: 0)).not_to be_valid
  end

  describe "#signed_amount" do
    it "is negative for an expense" do
      transaction = build(:transaction, kind: :expense, amount: 100)
      expect(transaction.signed_amount).to eq(-100)
    end

    it "is positive for an income" do
      transaction = build(:transaction, kind: :income, amount: 100)
      expect(transaction.signed_amount).to eq(100)
    end
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/models/transaction_spec.rb
```

Expected: FAIL — `uninitialized constant Transaction`.

- [ ] **Step 3: Create the migration and model**

```bash
bundle exec rails generate migration CreateTransactions
```

Edit the migration:

```ruby
class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :kind, null: false, default: 0
      t.date :date, null: false
      t.references :account, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end
  end
end
```

Note: no `recurring_entry` reference yet — the `recurring_entries` table doesn't exist until Task 6, and `foreign_key: true` requires the target table to exist at migration time. Task 6 adds the `recurring_entry_id` column (via a separate migration) and the `belongs_to :recurring_entry` line once `RecurringEntry` exists. Do not add a stub `RecurringEntry` model to work around this.

```bash
bin/rails db:migrate
```

Create `app/models/transaction.rb`:

```ruby
class Transaction < ApplicationRecord
  enum :kind, { expense: 0, income: 1 }

  belongs_to :account
  belongs_to :category

  validates :description, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :date, presence: true

  def signed_amount
    income? ? amount : -amount
  end
end
```

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/models/transaction_spec.rb
```

Expected: `5 examples, 0 failures`.

- [ ] **Step 5: Add routes, controller and views**

Edit `config/routes.rb`:

```ruby
  resources :transactions
```

Create `app/controllers/transactions_controller.rb`:

```ruby
class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[show edit update destroy]

  def index
    @transactions = Transaction.includes(:account, :category).order(date: :desc)
  end

  def show; end

  def new
    @transaction = Transaction.new(date: Date.current)
  end

  def edit; end

  def create
    @transaction = Transaction.new(transaction_params)
    if @transaction.save
      redirect_to transactions_path, notice: "Lançamento criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to transactions_path, notice: "Lançamento atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_path, notice: "Lançamento removido."
  end

  private

  def set_transaction
    @transaction = Transaction.find(params[:id])
  end

  def transaction_params
    params.require(:transaction).permit(:description, :amount, :kind, :date, :account_id, :category_id)
  end
end
```

Create `app/views/transactions/_form.html.erb`:

```erb
<%= form_with model: transaction do |f| %>
  <div>
    <%= f.label :description %>
    <%= f.text_field :description %>
  </div>
  <div>
    <%= f.label :amount %>
    <%= f.number_field :amount, step: 0.01 %>
  </div>
  <div>
    <%= f.label :kind %>
    <%= f.select :kind, Transaction.kinds.keys %>
  </div>
  <div>
    <%= f.label :date %>
    <%= f.date_field :date %>
  </div>
  <div>
    <%= f.label :account_id, "Conta" %>
    <%= f.collection_select :account_id, Account.order(:name), :id, :name %>
  </div>
  <div>
    <%= f.label :category_id, "Categoria" %>
    <%= f.collection_select :category_id, Category.order(:name), :id, :name %>
  </div>
  <%= f.submit %>
<% end %>
```

Create `app/views/transactions/index.html.erb`:

```erb
<h1>Lançamentos</h1>
<%= link_to "Novo lançamento", new_transaction_path %>
<ul>
  <% @transactions.each do |transaction| %>
    <li>
      <%= transaction.date %> — <%= transaction.description %> —
      <%= transaction.kind %> — <%= transaction.amount %> —
      <%= transaction.account.name %> / <%= transaction.category.name %> —
      <%= link_to "Editar", edit_transaction_path(transaction) %> —
      <%= link_to "Remover", transaction_path(transaction), data: { turbo_method: :delete, turbo_confirm: "Tem certeza?" } %>
    </li>
  <% end %>
</ul>
```

Create `app/views/transactions/new.html.erb`:

```erb
<h1>Novo lançamento</h1>
<%= render "form", transaction: @transaction %>
```

Create `app/views/transactions/edit.html.erb`:

```erb
<h1>Editar lançamento</h1>
<%= render "form", transaction: @transaction %>
```

Create `app/views/transactions/show.html.erb`:

```erb
<h1><%= @transaction.description %></h1>
<p><%= @transaction.date %> — <%= @transaction.kind %> — <%= @transaction.amount %></p>
<%= link_to "Voltar", transactions_path %>
```

- [ ] **Step 6: Write the failing request spec**

Create `spec/requests/transactions_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account) }
  let(:category) { create(:category) }

  before { sign_in user }

  it "creates a transaction" do
    expect {
      post transactions_path, params: { transaction: { description: "Mercado", amount: 100, kind: "expense", date: Date.current, account_id: account.id, category_id: category.id } }
    }.to change(Transaction, :count).by(1)
    expect(response).to redirect_to(transactions_path)
  end

  it "does not create a transaction with a zero amount" do
    expect {
      post transactions_path, params: { transaction: { description: "Mercado", amount: 0, kind: "expense", date: Date.current, account_id: account.id, category_id: category.id } }
    }.not_to change(Transaction, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates a transaction" do
    transaction = create(:transaction, account: account, category: category)
    patch transaction_path(transaction), params: { transaction: { description: "Novo nome" } }
    expect(transaction.reload.description).to eq("Novo nome")
  end

  it "destroys a transaction" do
    transaction = create(:transaction, account: account, category: category)
    expect { delete transaction_path(transaction) }.to change(Transaction, :count).by(-1)
  end
end
```

- [ ] **Step 7: Run to verify it passes**

```bash
bundle exec rspec spec/requests/transactions_spec.rb
```

Expected: `4 examples, 0 failures`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Add Transaction model and CRUD"
```

---

### Task 6: RecurringEntry model + CRUD

**Files:**
- Create: `db/migrate/xxxx_create_recurring_entries.rb`
- Create: `db/migrate/xxxx_add_recurring_entry_to_transactions.rb`
- Create: `app/models/recurring_entry.rb`
- Modify: `app/models/transaction.rb`, `app/models/account.rb`, `app/models/category.rb`
- Create: `app/controllers/recurring_entries_controller.rb`
- Create: `app/views/recurring_entries/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`, `show.html.erb`
- Modify: `config/routes.rb`
- Create: `spec/factories/recurring_entries.rb`
- Test: `spec/models/recurring_entry_spec.rb`, `spec/requests/recurring_entries_spec.rb`

**Interfaces:**
- Consumes: `Account` (Task 3), `Category` (Task 4), `Transaction` (Task 5).
- Produces: `RecurringEntry` model — `description:string`, `amount:decimal`, `kind:integer` (enum `expense/income`), `day_of_month:integer`, `active:boolean`, `start_date:date`, `end_date:date` (nullable), `belongs_to :account`, `belongs_to :category`, `has_many :transactions`; scope `RecurringEntry.active`; `recurring_entries` RESTful routes. This task also adds `Transaction#recurring_entry_id` + `belongs_to :recurring_entry, optional: true` (Step 4), and `has_many :transactions`/`has_many :recurring_entries, dependent: :restrict_with_error` on `Account` and `Category` (Step 4). Used by Tasks 7, 9.

- [ ] **Step 1: Write the failing model test**

Create `spec/factories/recurring_entries.rb`:

```ruby
FactoryBot.define do
  factory :recurring_entry do
    description { "Aluguel" }
    amount { 1500 }
    kind { :expense }
    day_of_month { 5 }
    active { true }
    start_date { Date.current.beginning_of_month }
    end_date { nil }
    account
    category
  end
end
```

Create `spec/models/recurring_entry_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe RecurringEntry, type: :model do
  it "is valid with the factory defaults" do
    expect(build(:recurring_entry)).to be_valid
  end

  it "is invalid without a day_of_month" do
    expect(build(:recurring_entry, day_of_month: nil)).not_to be_valid
  end

  it "is invalid with a day_of_month greater than 31" do
    expect(build(:recurring_entry, day_of_month: 32)).not_to be_valid
  end

  it "is invalid when end_date is before start_date" do
    entry = build(:recurring_entry, start_date: Date.new(2026, 3, 1), end_date: Date.new(2026, 2, 1))
    expect(entry).not_to be_valid
    expect(entry.errors[:end_date]).to be_present
  end

  describe ".active" do
    it "returns only active entries" do
      active_entry = create(:recurring_entry, active: true)
      create(:recurring_entry, active: false)
      expect(RecurringEntry.active).to contain_exactly(active_entry)
    end
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/models/recurring_entry_spec.rb
```

Expected: FAIL — `uninitialized constant RecurringEntry`.

- [ ] **Step 3: Create the migration and model**

```bash
bundle exec rails generate migration CreateRecurringEntries
```

Edit the migration:

```ruby
class CreateRecurringEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_entries do |t|
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :kind, null: false, default: 0
      t.references :account, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.integer :day_of_month, null: false
      t.boolean :active, null: false, default: true
      t.date :start_date, null: false
      t.date :end_date

      t.timestamps
    end
  end
end
```

```bash
bin/rails db:migrate
```

Then add the `recurring_entry` foreign key to `transactions` (created without it in Task 5):

```bash
bundle exec rails generate migration AddRecurringEntryToTransactions recurring_entry:references
bin/rails db:migrate
```

Create `app/models/recurring_entry.rb`:

```ruby
class RecurringEntry < ApplicationRecord
  enum :kind, { expense: 0, income: 1 }

  belongs_to :account
  belongs_to :category
  has_many :transactions, dependent: :nullify

  validates :description, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :day_of_month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }
  validates :start_date, presence: true

  validate :end_date_after_start_date

  scope :active, -> { where(active: true) }

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    errors.add(:end_date, "deve ser posterior à data de início") if end_date < start_date
  end
end
```

- [ ] **Step 4: Wire up the associations that could only be declared once `RecurringEntry` exists**

Edit `app/models/transaction.rb`, add `belongs_to :recurring_entry, optional: true` alongside the existing `belongs_to` lines:

```ruby
  belongs_to :account
  belongs_to :category
  belongs_to :recurring_entry, optional: true
```

Edit `app/models/account.rb`, add inside the `Account` class (above `validates`):

```ruby
  has_many :transactions, dependent: :restrict_with_error
  has_many :recurring_entries, dependent: :restrict_with_error
```

Edit `app/models/category.rb`, add inside the `Category` class (above `validates`):

```ruby
  has_many :transactions, dependent: :restrict_with_error
  has_many :recurring_entries, dependent: :restrict_with_error
```

- [ ] **Step 5: Run to verify it passes**

```bash
bundle exec rspec spec/models/recurring_entry_spec.rb
```

Expected: `5 examples, 0 failures`.

- [ ] **Step 6: Add routes, controller and views**

Edit `config/routes.rb`:

```ruby
  resources :recurring_entries
```

Create `app/controllers/recurring_entries_controller.rb`:

```ruby
class RecurringEntriesController < ApplicationController
  before_action :set_recurring_entry, only: %i[show edit update destroy]

  def index
    @recurring_entries = RecurringEntry.includes(:account, :category).order(:description)
  end

  def show; end

  def new
    @recurring_entry = RecurringEntry.new(start_date: Date.current)
  end

  def edit; end

  def create
    @recurring_entry = RecurringEntry.new(recurring_entry_params)
    if @recurring_entry.save
      redirect_to recurring_entries_path, notice: "Recorrência criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @recurring_entry.update(recurring_entry_params)
      redirect_to recurring_entries_path, notice: "Recorrência atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurring_entry.destroy
    redirect_to recurring_entries_path, notice: "Recorrência removida."
  end

  private

  def set_recurring_entry
    @recurring_entry = RecurringEntry.find(params[:id])
  end

  def recurring_entry_params
    params.require(:recurring_entry).permit(:description, :amount, :kind, :day_of_month, :active, :start_date, :end_date, :account_id, :category_id)
  end
end
```

Create `app/views/recurring_entries/_form.html.erb`:

```erb
<%= form_with model: recurring_entry do |f| %>
  <div>
    <%= f.label :description %>
    <%= f.text_field :description %>
  </div>
  <div>
    <%= f.label :amount %>
    <%= f.number_field :amount, step: 0.01 %>
  </div>
  <div>
    <%= f.label :kind %>
    <%= f.select :kind, RecurringEntry.kinds.keys %>
  </div>
  <div>
    <%= f.label :day_of_month %>
    <%= f.number_field :day_of_month, min: 1, max: 31 %>
  </div>
  <div>
    <%= f.label :active %>
    <%= f.check_box :active %>
  </div>
  <div>
    <%= f.label :start_date %>
    <%= f.date_field :start_date %>
  </div>
  <div>
    <%= f.label :end_date %>
    <%= f.date_field :end_date %>
  </div>
  <div>
    <%= f.label :account_id, "Conta" %>
    <%= f.collection_select :account_id, Account.order(:name), :id, :name %>
  </div>
  <div>
    <%= f.label :category_id, "Categoria" %>
    <%= f.collection_select :category_id, Category.order(:name), :id, :name %>
  </div>
  <%= f.submit %>
<% end %>
```

Create `app/views/recurring_entries/index.html.erb`:

```erb
<h1>Gastos e receitas fixas</h1>
<%= link_to "Nova recorrência", new_recurring_entry_path %>
<ul>
  <% @recurring_entries.each do |entry| %>
    <li>
      <%= entry.description %> — dia <%= entry.day_of_month %> — <%= entry.kind %> — <%= entry.amount %> —
      <%= entry.account.name %> / <%= entry.category.name %> — <%= entry.active? ? "ativa" : "inativa" %> —
      <%= link_to "Editar", edit_recurring_entry_path(entry) %> —
      <%= link_to "Remover", recurring_entry_path(entry), data: { turbo_method: :delete, turbo_confirm: "Tem certeza?" } %>
    </li>
  <% end %>
</ul>
```

Create `app/views/recurring_entries/new.html.erb`:

```erb
<h1>Nova recorrência</h1>
<%= render "form", recurring_entry: @recurring_entry %>
```

Create `app/views/recurring_entries/edit.html.erb`:

```erb
<h1>Editar recorrência</h1>
<%= render "form", recurring_entry: @recurring_entry %>
```

Create `app/views/recurring_entries/show.html.erb`:

```erb
<h1><%= @recurring_entry.description %></h1>
<p>Dia <%= @recurring_entry.day_of_month %> — <%= @recurring_entry.kind %> — <%= @recurring_entry.amount %></p>
<%= link_to "Voltar", recurring_entries_path %>
```

- [ ] **Step 7: Write the failing request spec**

Create `spec/requests/recurring_entries_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "RecurringEntries", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account) }
  let(:category) { create(:category) }

  before { sign_in user }

  it "creates a recurring entry" do
    expect {
      post recurring_entries_path, params: { recurring_entry: { description: "Aluguel", amount: 1500, kind: "expense", day_of_month: 5, active: true, start_date: Date.current, account_id: account.id, category_id: category.id } }
    }.to change(RecurringEntry, :count).by(1)
    expect(response).to redirect_to(recurring_entries_path)
  end

  it "does not create a recurring entry with an invalid day_of_month" do
    expect {
      post recurring_entries_path, params: { recurring_entry: { description: "Aluguel", amount: 1500, kind: "expense", day_of_month: 40, active: true, start_date: Date.current, account_id: account.id, category_id: category.id } }
    }.not_to change(RecurringEntry, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "updates a recurring entry" do
    entry = create(:recurring_entry, account: account, category: category)
    patch recurring_entry_path(entry), params: { recurring_entry: { active: false } }
    expect(entry.reload.active).to be(false)
  end

  it "destroys a recurring entry" do
    entry = create(:recurring_entry, account: account, category: category)
    expect { delete recurring_entry_path(entry) }.to change(RecurringEntry, :count).by(-1)
  end
end
```

- [ ] **Step 8: Run to verify it passes**

```bash
bundle exec rspec spec/requests/recurring_entries_spec.rb
```

Expected: `4 examples, 0 failures`.

- [ ] **Step 9: Run the full suite**

```bash
bundle exec rspec
```

Expected: all examples pass (this exercises the Account/Category/Transaction associations added in Step 4 together with everything from Tasks 1-5).

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "Add RecurringEntry model and CRUD"
```

---

### Task 7: RecurringEntryGenerator service

**Files:**
- Create: `app/services/recurring_entry_generator.rb`
- Test: `spec/services/recurring_entry_generator_spec.rb`

**Interfaces:**
- Consumes: `RecurringEntry.active` scope, `RecurringEntry#transactions` (Task 6); `Transaction` model (Task 5).
- Produces: `RecurringEntryGenerator.call(today: Date.current)` — creates one `Transaction` per due, not-yet-generated `RecurringEntry`. Used by Task 8.

- [ ] **Step 1: Write the failing test for basic generation**

Create `spec/services/recurring_entry_generator_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe RecurringEntryGenerator do
  let(:account) { create(:account) }
  let(:category) { create(:category) }

  it "generates a transaction for an entry due today" do
    entry = create(:recurring_entry, account: account, category: category, day_of_month: 10, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 10))

    transaction = entry.transactions.sole
    expect(transaction.amount).to eq(entry.amount)
    expect(transaction.kind).to eq(entry.kind)
    expect(transaction.date).to eq(Date.new(2026, 3, 10))
    expect(transaction.account).to eq(account)
    expect(transaction.category).to eq(category)
  end

  it "does not generate a transaction before the entry's day_of_month" do
    entry = create(:recurring_entry, account: account, category: category, day_of_month: 20, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 10))

    expect(entry.transactions).to be_empty
  end

  it "does not generate a duplicate transaction in the same month" do
    entry = create(:recurring_entry, account: account, category: category, day_of_month: 5, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 5))
    described_class.call(today: Date.new(2026, 3, 20))

    expect(entry.transactions.count).to eq(1)
  end

  it "does not generate a transaction for an inactive entry" do
    entry = create(:recurring_entry, account: account, category: category, day_of_month: 5, active: false, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 5))

    expect(entry.transactions).to be_empty
  end

  it "does not generate a transaction after end_date" do
    entry = create(:recurring_entry, account: account, category: category, day_of_month: 5, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 2, 28))

    described_class.call(today: Date.new(2026, 3, 5))

    expect(entry.transactions).to be_empty
  end

  it "generates the next month's transaction after end of previous month" do
    entry = create(:recurring_entry, account: account, category: category, day_of_month: 5, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 3, 5))
    described_class.call(today: Date.new(2026, 4, 5))

    expect(entry.transactions.count).to eq(2)
  end

  it "clamps a day_of_month past the end of a shorter month to the last day of that month" do
    entry = create(:recurring_entry, account: account, category: category, day_of_month: 31, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 4, 30))

    transaction = entry.transactions.sole
    expect(transaction.date).to eq(Date.new(2026, 4, 30))
  end

  it "does not generate the clamped transaction before the last day of a shorter month" do
    entry = create(:recurring_entry, account: account, category: category, day_of_month: 31, start_date: Date.new(2026, 1, 1))

    described_class.call(today: Date.new(2026, 4, 29))

    expect(entry.transactions).to be_empty
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/services/recurring_entry_generator_spec.rb
```

Expected: FAIL — `uninitialized constant RecurringEntryGenerator`.

- [ ] **Step 3: Implement the service**

Create `app/services/recurring_entry_generator.rb`:

```ruby
class RecurringEntryGenerator
  def self.call(today: Date.current)
    new(today: today).call
  end

  def initialize(today:)
    @today = today
  end

  def call
    due_entries.find_each { |entry| generate_transaction_for(entry) }
  end

  private

  attr_reader :today

  def due_entries
    RecurringEntry.active
                  .where("day_of_month <= ? OR (? = ? AND day_of_month > ?)",
                         today.day, today.day, today.end_of_month.day, today.end_of_month.day)
                  .where("start_date <= ?", today)
                  .where("end_date IS NULL OR end_date >= ?", today)
  end

  def generate_transaction_for(entry)
    return if entry.transactions.where(date: today.beginning_of_month..today.end_of_month).exists?

    entry.transactions.create!(
      description: entry.description,
      amount: entry.amount,
      kind: entry.kind,
      account: entry.account,
      category: entry.category,
      date: transaction_date_for(entry)
    )
  end

  def transaction_date_for(entry)
    day = [ entry.day_of_month, today.end_of_month.day ].min
    Date.new(today.year, today.month, day)
  end
end
```

Note on `due_entries`: the second half of the `OR` (`today.day == today.end_of_month.day AND day_of_month > today.end_of_month.day`) exists specifically so an entry whose `day_of_month` doesn't fit in the current month (e.g. 31 in April) fires once, on the month's last day, instead of never matching `day_of_month <= today.day` at all. Without it, `transaction_date_for`'s clamp is unreachable dead code — `due_entries` would already have filtered the entry out before the clamp could run. Both branches are covered by the "clamps a day_of_month past the end of a shorter month" and "does not generate the clamped transaction before the last day" tests above.

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/services/recurring_entry_generator_spec.rb
```

Expected: `8 examples, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add RecurringEntryGenerator service"
```

---

### Task 8: Scheduled job wiring

**Files:**
- Create: `app/jobs/generate_recurring_transactions_job.rb`
- Create: `config/recurring.yml`
- Test: `spec/jobs/generate_recurring_transactions_job_spec.rb`

**Interfaces:**
- Consumes: `RecurringEntryGenerator.call` (Task 7).
- Produces: `GenerateRecurringTransactionsJob` (Active Job), scheduled daily via Solid Queue's recurring tasks config.

- [ ] **Step 1: Write the failing job test**

Create `spec/jobs/generate_recurring_transactions_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe GenerateRecurringTransactionsJob, type: :job do
  it "delegates to RecurringEntryGenerator" do
    expect(RecurringEntryGenerator).to receive(:call)

    described_class.perform_now
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/jobs/generate_recurring_transactions_job_spec.rb
```

Expected: FAIL — `uninitialized constant GenerateRecurringTransactionsJob`.

- [ ] **Step 3: Implement the job**

Create `app/jobs/generate_recurring_transactions_job.rb`:

```ruby
class GenerateRecurringTransactionsJob < ApplicationJob
  queue_as :default

  def perform
    RecurringEntryGenerator.call
  end
end
```

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/jobs/generate_recurring_transactions_job_spec.rb
```

Expected: `1 example, 0 failures`.

- [ ] **Step 5: Schedule it with Solid Queue**

Create `config/recurring.yml`:

```yaml
production:
  generate_recurring_transactions:
    class: GenerateRecurringTransactionsJob
    schedule: every day at 6am

development:
  generate_recurring_transactions:
    class: GenerateRecurringTransactionsJob
    schedule: every day at 6am
```

- [ ] **Step 6: Run the full suite**

```bash
bundle exec rspec
```

Expected: all examples pass.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Schedule recurring transaction generation via Solid Queue"
```

---

### Task 9: Account balance and cash-flow projection methods

**Files:**
- Modify: `app/models/account.rb`
- Test: `spec/models/account_spec.rb`

**Interfaces:**
- Consumes: `Transaction#signed_amount` (Task 5), `RecurringEntry.active` (Task 6).
- Produces: `Account#current_balance(as_of: Date.current)`, `Account#projected_month_end_balance(as_of: Date.current)`. Used by Task 10.

- [ ] **Step 1: Write the failing tests**

Append to `spec/models/account_spec.rb` (inside the existing `RSpec.describe Account` block):

```ruby
  describe "#current_balance" do
    it "adds signed transaction amounts to the initial balance" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:transaction, account: account, category: category, kind: :expense, amount: 200, date: Date.new(2026, 3, 10))
      create(:transaction, account: account, category: category, kind: :income, amount: 300, date: Date.new(2026, 3, 15))

      expect(account.current_balance(as_of: Date.new(2026, 3, 20))).to eq(1100)
    end

    it "ignores transactions after the as_of date" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:transaction, account: account, category: category, kind: :expense, amount: 200, date: Date.new(2026, 3, 25))

      expect(account.current_balance(as_of: Date.new(2026, 3, 20))).to eq(1000)
    end
  end

  describe "#projected_month_end_balance" do
    it "adds pending active recurring entries for the rest of the month" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, account: account, category: category, kind: :expense, amount: 300, day_of_month: 25, start_date: Date.new(2026, 1, 1))
      create(:recurring_entry, account: account, category: category, kind: :income, amount: 500, day_of_month: 28, start_date: Date.new(2026, 1, 1))

      expect(account.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1200)
    end

    it "ignores recurring entries whose day_of_month already passed" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, account: account, category: category, kind: :expense, amount: 300, day_of_month: 5, start_date: Date.new(2026, 1, 1))

      expect(account.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1000)
    end

    it "ignores inactive recurring entries" do
      account = create(:account, initial_balance: 1000)
      category = create(:category)
      create(:recurring_entry, account: account, category: category, kind: :expense, amount: 300, day_of_month: 25, active: false, start_date: Date.new(2026, 1, 1))

      expect(account.projected_month_end_balance(as_of: Date.new(2026, 3, 10))).to eq(1000)
    end
  end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/models/account_spec.rb
```

Expected: FAIL — `NoMethodError: undefined method 'current_balance'`.

- [ ] **Step 3: Implement the methods**

Edit `app/models/account.rb`, adding inside the `Account` class:

```ruby
  def current_balance(as_of: Date.current)
    initial_balance + transactions.where(date: ..as_of).sum(&:signed_amount)
  end

  def projected_month_end_balance(as_of: Date.current)
    current_balance(as_of: as_of) + pending_recurring_signed_total(as_of: as_of)
  end

  private

  def pending_recurring_signed_total(as_of:)
    recurring_entries.active
                      .where("day_of_month > ?", as_of.day)
                      .where("start_date <= ?", as_of.end_of_month)
                      .where("end_date IS NULL OR end_date >= ?", as_of)
                      .sum { |entry| entry.income? ? entry.amount : -entry.amount }
  end
```

Note: keep existing `validates` calls above the new `private` section; do not duplicate `private`.

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/models/account_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add current and projected balance calculations to Account"
```

---

### Task 10: Dashboard

**Files:**
- Create: `app/controllers/dashboard_controller.rb`
- Create: `app/views/dashboard/index.html.erb`
- Modify: `config/routes.rb`
- Test: `spec/requests/dashboard_spec.rb`

**Interfaces:**
- Consumes: `Account#current_balance` / `Account#projected_month_end_balance` (Task 9), `Transaction` (Task 5).
- Produces: `GET /` → `DashboardController#index`, rendering per-account and total current/projected balances plus this month's transactions.

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/dashboard_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "shows account balances and this month's transactions" do
    account = create(:account, name: "Nubank", initial_balance: 1000)
    category = create(:category)
    create(:transaction, account: account, category: category, description: "Mercado", amount: 100, kind: :expense, date: Date.current)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nubank")
    expect(response.body).to include("Mercado")
  end

  it "redirects to sign in when not authenticated" do
    sign_out user
    get root_path
    expect(response).to redirect_to(new_user_session_path)
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Expected: FAIL — no route matches `root_path` (or similar).

- [ ] **Step 3: Add the route**

Edit `config/routes.rb`, add near the top of the `draw do` block:

```ruby
  root "dashboard#index"
```

- [ ] **Step 4: Implement the controller**

Create `app/controllers/dashboard_controller.rb`:

```ruby
class DashboardController < ApplicationController
  def index
    @today = Date.current
    @accounts = Account.order(:name)
    @total_current_balance = @accounts.sum { |account| account.current_balance(as_of: @today) }
    @total_projected_balance = @accounts.sum { |account| account.projected_month_end_balance(as_of: @today) }
    @transactions = Transaction.includes(:account, :category)
                                .where(date: @today.beginning_of_month..@today.end_of_month)
                                .order(date: :desc)
  end
end
```

- [ ] **Step 5: Implement the view**

Create `app/views/dashboard/index.html.erb`:

```erb
<h1>Painel</h1>

<h2>Contas</h2>
<table>
  <thead>
    <tr>
      <th>Conta</th>
      <th>Saldo atual</th>
      <th>Previsto até o fim do mês</th>
    </tr>
  </thead>
  <tbody>
    <% @accounts.each do |account| %>
      <tr>
        <td><%= account.name %></td>
        <td><%= number_to_currency(account.current_balance(as_of: @today), unit: "R$ ") %></td>
        <td><%= number_to_currency(account.projected_month_end_balance(as_of: @today), unit: "R$ ") %></td>
      </tr>
    <% end %>
  </tbody>
  <tfoot>
    <tr>
      <td>Total</td>
      <td><%= number_to_currency(@total_current_balance, unit: "R$ ") %></td>
      <td><%= number_to_currency(@total_projected_balance, unit: "R$ ") %></td>
    </tr>
  </tfoot>
</table>

<h2>Lançamentos do mês</h2>
<ul>
  <% @transactions.each do |transaction| %>
    <li>
      <%= transaction.date %> — <%= transaction.description %> — <%= transaction.kind %> —
      <%= number_to_currency(transaction.amount, unit: "R$ ") %> —
      <%= transaction.account.name %> / <%= transaction.category.name %>
    </li>
  <% end %>
</ul>
```

- [ ] **Step 6: Run to verify it passes**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Expected: `2 examples, 0 failures`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Add dashboard with account balances and monthly transactions"
```

---

### Task 11: Navigation layout

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Test: `spec/requests/dashboard_spec.rb` (extend)

**Interfaces:**
- Consumes: all routes from Tasks 3, 4, 5, 6, 10.
- Produces: a nav bar present on every authenticated page linking to Painel, Contas, Categorias, Lançamentos, Recorrências, and a sign-out link.

- [ ] **Step 1: Write the failing test**

Append to `spec/requests/dashboard_spec.rb`, inside the `RSpec.describe "Dashboard"` block:

```ruby
  it "shows navigation links" do
    get root_path

    expect(response.body).to include(accounts_path)
    expect(response.body).to include(categories_path)
    expect(response.body).to include(transactions_path)
    expect(response.body).to include(recurring_entries_path)
  end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Expected: FAIL — nav links not present in the response body.

- [ ] **Step 3: Add navigation to the layout**

Edit `app/views/layouts/application.html.erb`, inside `<body>`, before `<%= yield %>`:

```erb
    <% if user_signed_in? %>
      <nav>
        <%= link_to "Painel", root_path %>
        <%= link_to "Contas", accounts_path %>
        <%= link_to "Categorias", categories_path %>
        <%= link_to "Lançamentos", transactions_path %>
        <%= link_to "Recorrências", recurring_entries_path %>
        <%= button_to "Sair", destroy_user_session_path, method: :delete %>
      </nav>
    <% end %>

    <% flash.each do |type, message| %>
      <p class="flash <%= type %>"><%= message %></p>
    <% end %>
```

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Expected: `3 examples, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add authenticated navigation layout"
```

---

### Task 12: README, seed instructions, full suite check

**Files:**
- Create: `README.md`
- Test: none new (final full-suite verification)

**Interfaces:**
- Consumes: everything from Tasks 1–11.
- Produces: documented setup/seed/run instructions; a final green `bundle exec rspec` run confirming the MVP is complete.

- [ ] **Step 1: Write the README**

Create `README.md`:

```markdown
# Gestão Financeira

Aplicação pessoal de gestão financeira em Ruby on Rails: contas, categorias,
gastos/receitas fixas (recorrentes) e avulsas, e um painel com saldo atual e
previsto do mês.

## Setup

    bundle install
    bin/rails db:create db:migrate

## Criar o usuário

Defina as variáveis de ambiente e rode o seed:

    SEED_USER_EMAIL=seu@email.com SEED_USER_PASSWORD='SenhaForte#1' bin/rails db:seed

A senha precisa ter ao menos uma letra maiúscula e um caractere especial.

## Rodar localmente

    bin/rails server

## Rodar os testes

    bundle exec rspec

## Geração automática de lançamentos fixos

Um job diário (`GenerateRecurringTransactionsJob`, agendado em
`config/recurring.yml` via Solid Queue) gera a transação do mês para cada
gasto/receita fixa ativa, no dia configurado (`day_of_month`). Rodar
manualmente:

    bin/rails runner "RecurringEntryGenerator.call"
```

- [ ] **Step 2: Run the full test suite**

```bash
bundle exec rspec
```

Expected: all examples pass, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "Add README with setup and usage instructions"
```

---

## Self-Review Notes

- **Spec coverage:** Account/Category/Transaction/RecurringEntry CRUD (Tasks 3–6), automatic monthly generation with idempotency (Tasks 7–8), current + projected cash-flow dashboard (Tasks 9–10), Devise auth with custom password complexity (Task 2), Postgres + decimal columns (Task 1, all migrations), navigation (Task 11) — all spec sections are covered.
- **Type consistency:** `Transaction#signed_amount`, `Account#current_balance(as_of:)`, `Account#projected_month_end_balance(as_of:)`, and `RecurringEntryGenerator.call(today:)` are defined once (Tasks 5, 9, 7) and referenced identically wherever consumed (Tasks 8, 10).
- **Out of scope** (per spec, left for future specs): credit card invoice logic, installment purchases, category budgets, savings goals, charts/reports, statement import, multi-user/multi-currency.
