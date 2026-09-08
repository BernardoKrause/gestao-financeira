# Rate Limiting (rack-attack) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add rate limiting to the Rails app using rack-attack, reusing the existing `solid_cache` store, to protect against login brute-force and general request/resource abuse.

**Architecture:** A single `config/initializers/rack_attack.rb` configures `Rack::Attack` (store, safelist, throttle rules, custom 429 responder, warn-level logging). No new infra — the gem's Rack middleware is auto-inserted. Tests isolate `Rack::Attack`'s cache from the real `solid_cache` via a support file that swaps in an in-memory store and force-enables the middleware only for the specs that need it.

**Tech Stack:** Ruby on Rails 8.1, `rack-attack` gem, RSpec request specs, `solid_cache` (production store), `ActiveSupport::Cache::MemoryStore` (test store).

## Global Constraints

- Spec doc: `docs/superpowers/specs/2026-09-08-rate-limiting-design.md` — read it before starting if anything below is ambiguous.
- All throttles key on `req.ip` unless stated otherwise; there is **no global (all-IPs-combined) throttle** — do not add one, it was explicitly rejected as a design (creates its own DoS vector).
- `Rack::Attack.cache.store = Rails.cache` in production/development (reuses `solid_cache`); tests always use a dedicated `ActiveSupport::Cache::MemoryStore`, never the real `Rails.cache`.
- `Rack::Attack.enabled` is `true` only in `production` by default; test specs that exercise throttling must explicitly force it on and reset it after.
- Every throttle limit, period, and route from the spec's table must be implemented exactly as specified — do not invent additional throttles or change the numbers.
- Test commands in this repo run via `bundle exec rspec` (there is no `bin/rspec`).
- All user-facing strings (the 429 page) must be in Portuguese (pt-BR), matching the rest of the app.

---

### Task 1: Install rack-attack, base config, and general request throttle

**Files:**
- Modify: `Gemfile` (add `gem "rack-attack"`)
- Modify: `Gemfile.lock` (via `bundle install`)
- Create: `config/initializers/rack_attack.rb`
- Create: `spec/support/rack_attack.rb`
- Modify: `spec/rails_helper.rb` (require the new support file — support files aren't auto-required in this repo, see the commented-out glob line)
- Test: `spec/requests/rack_attack_spec.rb`

**Interfaces:**
- Produces: `Rack::Attack` initializer with `Rack::Attack.cache.store`, `Rack::Attack.enabled`, `Rack::Attack.safelist("allow health check")`, and throttle `"req/ip"`. Later tasks (2, 3, 4) add more throttles and the responder to this same file.
- Produces: `spec/support/rack_attack.rb` defines a shared context/helper the later tasks' specs also use: wraps examples with `Rack::Attack.enabled = true`, swaps `Rack::Attack.cache.store` to a fresh `ActiveSupport::Cache::MemoryStore`, clears it before each example, and restores the original store/enabled flag after. Exposed as an RSpec shared context named `:rack_attack` applied via `describe "...", rack_attack: true`.

- [ ] **Step 1: Add the gem and install it**

Edit `Gemfile`, add this line right after `gem "avo", ">= 4.0.0"`:

```ruby
gem "rack-attack"
```

Run: `bundle install`
Expected: `Gemfile.lock` gains a `rack-attack` entry; command exits 0.

- [ ] **Step 2: Create the test isolation support file**

Create `spec/support/rack_attack.rb`:

```ruby
RSpec.configure do |config|
  config.around(:example, rack_attack: true) do |example|
    original_store = Rack::Attack.cache.store
    original_enabled = Rack::Attack.enabled

    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true

    example.run

    Rack::Attack.cache.store = original_store
    Rack::Attack.enabled = original_enabled
  end
end
```

- [ ] **Step 3: Require support files in rails_helper**

In `spec/rails_helper.rb`, find the commented-out line:

```ruby
# Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }
```

Uncomment it (remove the leading `# `).

- [ ] **Step 4: Write the failing test for the general throttle and the health-check safelist**

Create `spec/requests/rack_attack_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Rack::Attack", type: :request, rack_attack: true do
  describe "general request throttle" do
    it "allows requests under the limit" do
      300.times { get root_path }

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "blocks the request that exceeds the limit" do
      300.times { get root_path }
      get root_path

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "health check safelist" do
    it "never blocks /up even past the general limit" do
      301.times { get root_path }

      get "/up"

      expect(response).to have_http_status(:ok)
    end
  end
end
```

- [ ] **Step 5: Run the tests to verify they fail**

Run: `bundle exec rspec spec/requests/rack_attack_spec.rb`
Expected: FAIL — either `uninitialized constant Rack::Attack` or all requests return 200 (no throttle configured yet).

- [ ] **Step 6: Implement the initializer**

Create `config/initializers/rack_attack.rb`:

```ruby
class Rack::Attack
  self.cache.store = Rails.cache
  self.enabled = Rails.env.production?

  safelist("allow health check") do |req|
    req.path == "/up"
  end

  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets/")
  end
end
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `bundle exec rspec spec/requests/rack_attack_spec.rb`
Expected: PASS (3 examples, 0 failures).

- [ ] **Step 8: Commit**

```bash
git add Gemfile Gemfile.lock config/initializers/rack_attack.rb spec/support/rack_attack.rb spec/rails_helper.rb spec/requests/rack_attack_spec.rb
git commit -m "feat: adiciona rack-attack com throttle geral por IP

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0164cQGPn7wjWdG9JRdsKKKu"
```

---

### Task 2: Login throttles (by IP and by email)

**Files:**
- Modify: `config/initializers/rack_attack.rb`
- Test: `spec/requests/rack_attack_spec.rb`

**Interfaces:**
- Consumes: the `rack_attack: true` shared context from Task 1 (`spec/support/rack_attack.rb`); the `Rack::Attack` class reopened in the same initializer file from Task 1.
- Produces: throttles `"logins/ip"` and `"logins/email"`, both matching `POST /users/sign_in`. No new files or names consumed by later tasks.

- [ ] **Step 1: Write the failing tests**

Add to `spec/requests/rack_attack_spec.rb`, inside the top-level `RSpec.describe "Rack::Attack"` block:

```ruby
  describe "login throttle by IP" do
    it "allows 5 attempts from the same IP in 20 seconds" do
      user = create(:user)

      5.times do
        post user_session_path, params: { user: { email: user.email, password: "wrong" } }
      end

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "blocks the 6th attempt from the same IP in 20 seconds" do
      user = create(:user)

      6.times do
        post user_session_path, params: { user: { email: user.email, password: "wrong" } }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "login throttle by email" do
    it "blocks the 6th attempt against the same email even from different IPs" do
      user = create(:user)

      6.times do |n|
        post user_session_path,
          params: { user: { email: user.email, password: "wrong" } },
          headers: { "REMOTE_ADDR" => "10.0.0.#{n}" }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/requests/rack_attack_spec.rb`
Expected: FAIL — the two new "blocks the 6th attempt" examples fail (login attempts aren't throttled yet), the "allows 5 attempts" example passes.

- [ ] **Step 3: Implement the login throttles**

In `config/initializers/rack_attack.rb`, add inside the `class Rack::Attack` body (after the `req/ip` throttle from Task 1):

```ruby
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/requests/rack_attack_spec.rb`
Expected: PASS (7 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add config/initializers/rack_attack.rb spec/requests/rack_attack_spec.rb
git commit -m "feat: adiciona throttle de login por IP e por e-mail

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0164cQGPn7wjWdG9JRdsKKKu"
```

---

### Task 3: Password reset throttles (by IP and by email)

**Files:**
- Modify: `config/initializers/rack_attack.rb`
- Test: `spec/requests/rack_attack_spec.rb`

**Interfaces:**
- Consumes: the `rack_attack: true` shared context from Task 1; the `Rack::Attack` class from Task 1/2's initializer.
- Produces: throttles `"password_resets/ip"` and `"password_resets/email"`, matching `POST /users/password`.

- [ ] **Step 1: Write the failing tests**

Add to `spec/requests/rack_attack_spec.rb`, inside the top-level describe block:

```ruby
  describe "password reset throttle by IP" do
    it "allows 5 attempts from the same IP in 20 minutes" do
      user = create(:user)

      5.times do
        post user_password_path, params: { user: { email: user.email } }
      end

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "blocks the 6th attempt from the same IP in 20 minutes" do
      user = create(:user)

      6.times do
        post user_password_path, params: { user: { email: user.email } }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "password reset throttle by email" do
    it "blocks the 6th attempt against the same email even from different IPs" do
      user = create(:user)

      6.times do |n|
        post user_password_path,
          params: { user: { email: user.email } },
          headers: { "REMOTE_ADDR" => "10.0.1.#{n}" }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/requests/rack_attack_spec.rb`
Expected: FAIL — the two "blocks the 6th attempt" examples fail; the "allows 5 attempts" example passes.

- [ ] **Step 3: Implement the password reset throttles**

In `config/initializers/rack_attack.rb`, add inside the `class Rack::Attack` body (after the login throttles from Task 2):

```ruby
  throttle("password_resets/ip", limit: 5, period: 20.minutes) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  throttle("password_resets/email", limit: 5, period: 20.minutes) do |req|
    if req.path == "/users/password" && req.post?
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/requests/rack_attack_spec.rb`
Expected: PASS (10 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add config/initializers/rack_attack.rb spec/requests/rack_attack_spec.rb
git commit -m "feat: adiciona throttle de recuperação de senha por IP e por e-mail

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0164cQGPn7wjWdG9JRdsKKKu"
```

---

### Task 4: Custom 429 response and warn-level logging

**Files:**
- Create: `public/429.html`
- Modify: `config/initializers/rack_attack.rb`
- Test: `spec/requests/rack_attack_spec.rb`

**Interfaces:**
- Consumes: the `rack_attack: true` shared context and the throttled-request setup pattern from Task 1's `"req/ip"` throttle (301 requests to `root_path` trips it).
- Produces: `Rack::Attack.throttled_responder` and an `ActiveSupport::Notifications.subscribe("throttle.rack_attack")` warn log — nothing later depends on these by name, this is the last task.

- [ ] **Step 1: Write the failing tests**

Add to `spec/requests/rack_attack_spec.rb`, inside the top-level describe block:

```ruby
  describe "throttled response" do
    it "returns a Portuguese 429 page with a Retry-After header" do
      301.times { get root_path }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
      expect(response.body).to include("Muitas requisições")
    end

    it "logs a warning with the IP and the matched rule" do
      allow(Rails.logger).to receive(:warn).and_call_original

      301.times { get root_path }

      expect(Rails.logger).to have_received(:warn).with(/rack-attack/i).at_least(:once)
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/requests/rack_attack_spec.rb`
Expected: FAIL — `response.body` doesn't include "Muitas requisições" (default rack-attack body is plain text "Retry later"), and `Rails.logger` never receives `:warn`.

- [ ] **Step 3: Create the 429 page**

Create `public/429.html` (same minimalist structure as `public/404.html`, in Portuguese, without the custom digit SVG art — plain text heading instead):

```html
<!doctype html>

<html lang="pt-BR">

  <head>

    <title>Muitas requisições (429 Too Many Requests)</title>

    <meta charset="utf-8">
    <meta name="viewport" content="initial-scale=1, width=device-width">
    <meta name="robots" content="noindex, nofollow">

    <style>

      *, *::before, *::after {
        box-sizing: border-box;
      }

      * {
        margin: 0;
      }

      html {
        font-size: 16px;
      }

      body {
        background: #FFF;
        color: #261B23;
        display: grid;
        font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, Aptos, Roboto, "Segoe UI", "Helvetica Neue", Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji";
        font-size: clamp(1rem, 2.5vw, 2rem);
        -webkit-font-smoothing: antialiased;
        font-style: normal;
        font-weight: 400;
        letter-spacing: -0.0025em;
        line-height: 1.4;
        min-height: 100dvh;
        place-items: center;
        text-rendering: optimizeLegibility;
        -webkit-text-size-adjust: 100%;
      }

      @media (prefers-color-scheme: dark) {
        body {
          background: #101010;
          color: #e0e0e0;
        }
      }

      main {
        display: grid;
        gap: 1em;
        padding: 2em;
        place-items: center;
        text-align: center;
      }

      main article {
        width: min(100%, 30em);
      }

      main article p {
        font-size: 75%;
      }

    </style>

  </head>

  <body>

    <!-- This file lives in public/429.html -->

    <main>
      <article>
        <p><strong>Muitas requisições.</strong> Você atingiu o limite de requisições. Aguarde alguns instantes e tente novamente.</p>
      </article>
    </main>

  </body>

</html>
```

- [ ] **Step 4: Implement the responder and the log subscriber**

In `config/initializers/rack_attack.rb`, add after the throttle rules but still inside `class Rack::Attack`:

```ruby
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    retry_after = match_data[:period] - (match_data[:epoch_time] % match_data[:period])

    headers = {
      "Content-Type" => "text/html",
      "Retry-After" => retry_after.to_s
    }

    [ 429, headers, [ File.read(Rails.root.join("public/429.html")) ] ]
  end
```

After the `class Rack::Attack ... end` block (top level of the initializer file), add:

```ruby
ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _instrumenter_id, payload|
  request = payload[:request]
  match_data = request.env["rack.attack.match_data"]

  Rails.logger.warn(
    "[rack-attack] blocked ip=#{request.ip} rule=#{request.env['rack.attack.matched']} discriminator=#{match_data[:discriminator]}"
  )
end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bundle exec rspec spec/requests/rack_attack_spec.rb`
Expected: PASS (12 examples, 0 failures).

- [ ] **Step 6: Run the full request suite to confirm no regressions**

Run: `bundle exec rspec spec/requests`
Expected: PASS, 0 failures. (`Rack::Attack.enabled` is `false` outside `production` by default, so pre-existing specs that don't opt into `rack_attack: true` are unaffected.)

- [ ] **Step 7: Commit**

```bash
git add public/429.html config/initializers/rack_attack.rb spec/requests/rack_attack_spec.rb
git commit -m "feat: adiciona página 429 customizada e log de bloqueios do rack-attack

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0164cQGPn7wjWdG9JRdsKKKu"
```
