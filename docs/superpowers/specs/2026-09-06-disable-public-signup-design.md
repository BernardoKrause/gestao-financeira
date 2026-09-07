# Desabilitar cadastro público de usuários

## Contexto

A aplicação está em desenvolvimento e ainda não deve permitir que desconhecidos criem contas. A partir de agora, a única forma de criar um novo usuário é pelo painel admin (Avo, `/admin`), restrito ao e-mail configurado em `Rails.application.credentials.admin_email` (ver [[gestao-financeira-admin-panel]]).

O bloqueio deve ser reversível: se no futuro o cadastro público for reaberto, a mudança deve ser fácil de desfazer.

## 1. Bloqueio do cadastro público

`Users::RegistrationsController` (`app/controllers/users/registrations_controller.rb`) passa a sobrescrever `new` e `create`, redirecionando para `new_user_session_path` com `alert: "Cadastro desabilitado. Contate o administrador."` antes de qualquer lógica do Devise.

As rotas do Devise (`devise_for :users, controllers: { registrations: "users/registrations" }`) permanecem intactas — `:registerable` continua habilitado no model `User`, então `edit`/`update` (tela "Minha conta") não são afetados.

O link "Criar conta" é removido de `app/views/devise/shared/_links.html.erb`. A view `app/views/devise/registrations/new.html.erb` permanece no repositório (nunca é renderizada, o redirect acontece antes).

Reversão futura: remover os métodos `new`/`create` do controller e o link de volta na view.

## 2. Onboarding automático independente da via de criação

Hoje `UserOnboarding` (cria o `Setting` inicial com saldo zero e as categorias padrão) só é chamado dentro de `Users::RegistrationsController#create`. Com o cadastro público bloqueado, a única via de criação passa a ser o Avo, que não passa por esse controller — um usuário criado lá ficaria sem `Setting`/categorias, e o dashboard quebraria (`@setting` seria `nil`).

Solução: mover o disparo do onboarding para um callback `after_create` no model `User`, para cobrir qualquer via de criação (Avo, console, ou uma futura reativação do cadastro público).

Para não quebrar as specs existentes que criam usuários via `create(:user)` e depois um `Setting`/categorias manualmente via factory (há índice único em `settings.user_id`, então um segundo `Setting` para o mesmo usuário falharia), o model ganha um atributo `skip_onboarding` (sem valor padrão explícito — `nil`, que o `unless:` trata como falso):

- `User#after_create :onboard_new_user, unless: :skip_onboarding`
- `onboard_new_user` chama `UserOnboarding.call(self)`
- A factory `:user` em `spec/factories/users.rb` passa `skip_onboarding { true }` por padrão
- Criação real (Avo, ou uma futura reativação do cadastro público) não seta a flag, então o onboarding roda normalmente
- `Users::RegistrationsController#create` deixa de chamar `UserOnboarding.call` diretamente (o callback do model já cobre)

## 3. Ajustes em `spec/requests/registrations_spec.rb`

- "shows the registration form" → passa a verificar que `GET new_user_registration_path` redireciona para o login
- "creates the user, signs in, seeds a setting and default categories, and redirects to root" → passa a verificar que `POST user_registration_path` **não** cria usuário e redireciona para o login
- Os testes de validação de senha fraca em `create` (mensagens em português) são removidos — a rota redireciona antes de qualquer validação
- O teste "allows registration even when a user already exists" é removido (não se aplica mais)
- O teste de `update` (edição da própria conta, incluindo a mensagem de erro de senha atual em português) permanece sem alteração

`spec/services/user_onboarding_spec.rb` permanece igual — testa `UserOnboarding.call` diretamente, sem depender do callback do model.

## Fora de escopo

- Qualquer mecanismo de feature flag/env var para ligar/desligar o cadastro sem alterar código (YAGNI para o estágio atual, com um único desenvolvedor operando).
- Alterar o fluxo de criação de usuários no Avo (`app/avo/resources/user.rb`) além do necessário — ele já suporta criar usuário com senha.
- Autoexclusão de conta (`destroy` em `Users::RegistrationsController`, herdado do Devise, não sobrescrito) continua funcionando; com o cadastro público bloqueado, isso é uma via de mão única — o usuário não pode mais se recadastrar sozinho, só o admin pode recriar a conta pelo Avo (perdendo os dados anteriores). Decisão consciente: manter como está por ora.
