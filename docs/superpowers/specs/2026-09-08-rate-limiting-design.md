# Rate limiting (rack-attack)

## Contexto

A aplicação roda em uma única VM Oracle Always Free (ARM, sem Redis, 1 processo Puma / 3 threads). Não houve nenhum incidente até agora — a medida é preventiva, motivada por duas preocupações com peso igual: consumo de recursos do servidor (scraping, bots, picos de tráfego) e brute-force/abuso do login (o cadastro público está desabilitado desde [[gestao-financeira-disable-signup]], mas a tela de login continua pública).

A solução usa a gem `rack-attack`, reaproveitando o `solid_cache` (Postgres-backed) já configurado como `Rails.cache` em produção — sem introduzir Redis ou qualquer infraestrutura nova.

## 1. Instalação e configuração base

- `gem "rack-attack"` no `Gemfile`.
- `config/initializers/rack_attack.rb`:
  - `Rack::Attack.cache.store = Rails.cache` — reusa o `solid_cache` existente.
  - `Rack::Attack.enabled = Rails.env.production?` — em `development`/`test` fica desligado por padrão (os specs de rate limit ligam explicitamente e usam um store isolado, ver seção 4).

O middleware é inserido automaticamente pelo Railtie da gem; nenhuma mudança em `config/application.rb`.

## 2. Regras de throttle

Todas por IP (`req.ip`), exceto onde indicado. Um limite "geral" (soma de todos os IPs) não é usado — criaria seu próprio vetor de negação de serviço, já que um único IP abusivo esgotaria a cota compartilhada de todos os usuários legítimos.

| Regra | Chave | Limite | Escopo |
|---|---|---|---|
| `req/ip` | IP | 300 req / 5 min | Todas as rotas, exceto `/assets/*` e `/up` |
| `logins/ip` | IP | 5 tentativas / 20s | `POST /users/sign_in` |
| `logins/email` | `params.dig("user", "email")&.downcase&.strip` | 5 tentativas / 20s | `POST /users/sign_in` (cobre ataque distribuído entre IPs contra a mesma conta) |
| `password_resets/ip` | IP | 5 / 20 min | `POST /users/password` |
| `password_resets/email` | `params.dig("user", "email")&.downcase&.strip` | 5 / 20 min | `POST /users/password` |

Notas:
- `/up` (health check usado por monitoramento externo) é adicionado à safelist (`Rack::Attack.safelist("allow health check")`) — nunca deve ser bloqueado.
- `/assets/*` fica fora do `req/ip` (matched via `req.path.start_with?("/assets/")` no bloco do throttle) — custo de servir é desprezível e um bloqueio ali não protege nada.
- As chaves de e-mail usam `.downcase&.strip` para não permitir contornar o limite variando capitalização/espaços; quando o e-mail estiver ausente do payload, a regra correspondente simplesmente não gera throttle (retorna `nil`, e o rack-attack ignora chaves `nil`).

## 3. Resposta ao bloqueio

- `Rack::Attack.throttled_responder` customizado retorna `429`, com o header `Retry-After` (calculado a partir de `match_data[:period]`, padrão do rack-attack).
- `public/429.html`: página estática em pt-BR, no mesmo estilo minimalista de `public/404.html`/`422.html`/`500.html` já existentes (sem branding elaborado).
- Log em nível `warn` a cada bloqueio, via `ActiveSupport::Notifications.subscribe("throttle.rack_attack")` em `config/initializers/rack_attack.rb`, contendo `req.ip` e o nome da regra (`payload[:request].env["rack.attack.match_data"][:discriminator]` etc. conforme a API da gem) — só para permitir investigação manual via log, sem alertas ativos.

## 4. Testes

Specs de request (RSpec) em `spec/requests/rack_attack_spec.rb`:

- Requisição além do limite geral (`req/ip`) retorna `429`.
- 6ª tentativa de login no mesmo IP em 20s retorna `429`; a 5ª ainda passa (`302`/`401` conforme credencial).
- 6ª tentativa de login com o mesmo e-mail vindo de IPs diferentes (`request.headers["REMOTE_ADDR"] =` variando) retorna `429`, cobrindo o throttle por e-mail isoladamente do throttle por IP.
- `GET /up` nunca é bloqueado mesmo estourando o limite geral antes.

Para isolar os testes do `solid_cache` real (evitar specs lentos/flaky por I/O no Postgres, e evitar que um teste vaze estado para o próximo):

- `Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new` em um `before(:suite)` (ou hook dedicado) em `rails_helper.rb`.
- `Rack::Attack.enabled = true` e `Rack::Attack.cache.store.clear` em torno de cada exemplo do describe de rate limiting (via `around`/`before`/`after` local ao arquivo, não globalmente — os demais specs de request não devem pagar esse custo nem ser afetados pelos throttles).

## Fora de escopo

- Blocklist permanente / ban progressivo (estilo fail2ban) para IPs reincidentes — YAGNI para o estágio atual (app pessoal, baixo tráfego, medida preventiva). Pode ser adicionado depois reaproveitando a mesma infraestrutura do rack-attack (`Rack::Attack.blocklist`) se necessário.
- Notificação ativa (e-mail/Slack) em caso de bloqueio — só log, conforme decidido.
- Rate limit diferenciado por usuário autenticado (ex.: limite maior para quem já está logado) — todas as rotas usam o mesmo throttle geral por IP.
- Alterar `config/cache.yml` (`max_size: 256MB`, sem `max_age`) — o cap de tamanho já existente é suficiente para as chaves de throttle, que têm TTL curto (period do throttle) e alto turnover.
