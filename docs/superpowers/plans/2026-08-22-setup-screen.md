# Setup Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a web form at `/setup` that creates the application's single user (replacing the need to run `bin/rails db:seed`), and that automatically stops working once a user exists.

**Architecture:** A plain (non-Devise) `SetupController` with `new`/`create` actions, gated by `User.exists?`, that creates a `User` and signs them in on success. The Devise sign-in view gets a conditional "Criar conta" link that only shows while no user exists.

**Tech Stack:** Ruby on Rails 8.x, Devise (`sign_in` helper, already globally available via `Devise::Controllers::Helpers`), RSpec + FactoryBot + Devise::Test::IntegrationHelpers (already configured in `spec/rails_helper.rb`).

## Global Constraints

- Single user, no public signup — the app must never allow more than one `User` row to be created through this screen. `SetupController` must redirect away (not render, not create) whenever `User.exists?` is true.
- Do NOT enable Devise's `:registerable` module and do NOT run `rails generate devise:views` — only override the one Devise view that needs to change (`app/views/devise/sessions/new.html.erb`).
- Reuse `User`'s existing `password_complexity` validation (`app/models/user.rb`) — do not duplicate or bypass it.
- Tests via RSpec; every task ships with passing tests before moving on.

---

### Task 1: SetupController — create the user, gated by `User.exists?`

**Files:**
- Create: `app/controllers/setup_controller.rb`
- Create: `app/views/setup/new.html.erb`
- Modify: `config/routes.rb`
- Test: `spec/requests/setup_spec.rb`

**Interfaces:**
- Consumes: `User` model with `password_complexity` validation (already in `app/models/user.rb`); `sign_in` (Devise helper, globally available).
- Produces: `GET /setup` → `new_setup_path`, `POST /setup` → `setup_path`. Both redirect to `new_user_session_path` with `alert: "Configuração já concluída."` whenever `User.exists?`. On success, `POST /setup` creates the `User`, signs them in, and redirects to `root_path`. Used by Task 2 (the login page links to `new_setup_path`).

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/setup_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Setup", type: :request do
  describe "when no user exists" do
    it "shows the setup form" do
      get new_setup_path

      expect(response).to have_http_status(:ok)
    end

    it "creates the user, signs in, and redirects to root" do
      expect {
        post setup_path, params: { user: { email: "dono@example.com", password: "Strong#Pass1", password_confirmation: "Strong#Pass1" } }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_path)

      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "does not create the user with an invalid password and re-renders the form" do
      expect {
        post setup_path, params: { user: { email: "dono@example.com", password: "weakpass", password_confirmation: "weakpass" } }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "when a user already exists" do
    before { create(:user) }

    it "redirects GET /setup to sign in without rendering the form" do
      get new_setup_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects POST /setup to sign in without creating another user" do
      expect {
        post setup_path, params: { user: { email: "outro@example.com", password: "Strong#Pass1", password_confirmation: "Strong#Pass1" } }
      }.not_to change(User, :count)

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/requests/setup_spec.rb
```

Expected: FAIL — no route matches `new_setup_path` (or similar routing error).

- [ ] **Step 3: Add the route**

Edit `config/routes.rb`, add inside `Rails.application.routes.draw do` (near `devise_for :users`):

```ruby
  resource :setup, only: %i[new create], controller: "setup"
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/setup_controller.rb`:

```ruby
class SetupController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :redirect_if_setup_complete

  def new
    @user = User.new
  end

  def create
    @user = User.new(setup_params)
    if @user.save
      sign_in(@user)
      redirect_to root_path, notice: "Conta criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_setup_complete
    redirect_to new_user_session_path, alert: "Configuração já concluída." if User.exists?
  end

  def setup_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
```

- [ ] **Step 5: Create the view**

Create `app/views/setup/new.html.erb`:

```erb
<h1>Criar conta</h1>

<%= form_with model: @user, url: setup_path do |f| %>
  <% if @user.errors.any? %>
    <div class="error-messages">
      <ul>
        <% @user.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div>
    <%= f.label :email %>
    <%= f.email_field :email, autofocus: true %>
  </div>

  <div>
    <%= f.label :password %>
    <%= f.password_field :password %>
  </div>

  <div>
    <%= f.label :password_confirmation, "Confirmação de senha" %>
    <%= f.password_field :password_confirmation %>
  </div>

  <%= f.submit "Criar conta" %>
<% end %>
```

- [ ] **Step 6: Run to verify it passes**

```bash
bundle exec rspec spec/requests/setup_spec.rb
```

Expected: `5 examples, 0 failures`.

- [ ] **Step 7: Run the full suite**

```bash
bundle exec rspec
```

Expected: all examples pass (this exercises the existing `authenticate_user!`/routing setup alongside the new controller).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Add self-disabling /setup screen to create the single user"
```

---

### Task 2: Conditional "Criar conta" link on the sign-in page

**Files:**
- Create: `app/views/devise/sessions/new.html.erb`
- Test: `spec/requests/sessions_spec.rb`

**Interfaces:**
- Consumes: `new_setup_path` (Task 1), `User.count`.
- Produces: the Devise sign-in page (`GET /users/sign_in`) shows a "Criar conta" link to `new_setup_path` only when `User.count.zero?`.

Devise's own gem provides the default `sessions/new` view (there is no `app/views/devise/` directory in this app yet — Devise falls back to its internal templates). This task overrides only that one file; do not run `rails generate devise:views` (that would generate every Devise view, which is out of scope).

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/sessions_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Sessions", type: :request do
  it "shows a 'Criar conta' link when no user exists yet" do
    get new_user_session_path

    expect(response.body).to include("Criar conta")
  end

  it "hides the 'Criar conta' link once a user exists" do
    create(:user)

    get new_user_session_path

    expect(response.body).not_to include("Criar conta")
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
bundle exec rspec spec/requests/sessions_spec.rb
```

Expected: FAIL on the first example — "Criar conta" not present in Devise's default sign-in page.

- [ ] **Step 3: Create the overridden sign-in view**

Create `app/views/devise/sessions/new.html.erb`:

```erb
<h2>Log in</h2>

<%= form_for(resource, as: resource_name, url: session_path(resource_name)) do |f| %>
  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <div class="field">
    <%= f.label :password %><br />
    <%= f.password_field :password, autocomplete: "current-password" %>
  </div>

  <div class="actions">
    <%= f.submit "Log in" %>
  </div>
<% end %>

<%= render "devise/shared/links" %>

<% if User.count.zero? %>
  <p><%= link_to "Criar conta", new_setup_path %></p>
<% end %>
```

Note: the `:rememberable` Devise module is not enabled on `User` (see `app/models/user.rb`), so the usual "remember me" checkbox block from Devise's default template is intentionally omitted here — it would never render anyway.

- [ ] **Step 4: Run to verify it passes**

```bash
bundle exec rspec spec/requests/sessions_spec.rb
```

Expected: `2 examples, 0 failures`.

- [ ] **Step 5: Run the full suite**

```bash
bundle exec rspec
```

Expected: all examples pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Show a self-hiding 'Criar conta' link on the sign-in page"
```

---

## Self-Review Notes

- **Spec coverage:** every requirement in `docs/superpowers/specs/2026-08-22-setup-screen-design.md` is covered — the gated route/controller, form reusing `User`'s existing validation, auto sign-in + redirect to root on success, the conditional login-page link, and `db/seeds.rb` is untouched (no task modifies it). The "fora de escopo" items (self-service edit/delete account, multi-user, password recovery UI) are correctly not implemented by any task.
- **Type consistency:** `new_setup_path` / `setup_path` (Task 1's routes) are referenced identically in Task 2's view. `User.exists?` (guard) and `User.count.zero?` (link visibility) are two different, both-correct checks for the same underlying fact (no rows) — not a mismatch.
- **No placeholders:** all steps contain literal, runnable code.
