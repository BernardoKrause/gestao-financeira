# Tela de Setup (criação do usuário único) — Design

Data: 2026-08-22

## Objetivo

Substituir a necessidade de rodar `bin/rails db:seed` no terminal por uma tela web para criar o usuário único da aplicação, mantendo o app **single-user, sem cadastro público**: a tela só funciona enquanto não existir nenhum usuário no banco, e se desativa sozinha depois disso.

## Contexto / decisão de escopo

A spec original (`2026-08-22-gestao-financeira-design.md`) definiu deliberadamente "sem cadastro público; usuário único criado via seed/console", para evitar que a aplicação hospedada aceite contas de qualquer pessoa que encontre a URL. Esta feature **não muda essa decisão** — ela só troca o mecanismo de criação do único usuário permitido (de "comando no terminal" para "formulário web"), preservando a regra de que só pode existir um usuário no sistema.

## Rotas e controller

- `SetupController` novo, **não** usa o módulo `:registerable` do Devise (evita trazer rotas de editar/cancelar conta, que não fazem sentido aqui).
- Rotas: `GET /setup` (`SetupController#new`) e `POST /setup` (`SetupController#create`).
- `before_action` em ambas as ações: se `User.exists?`, redireciona para `new_user_session_path` com aviso ("Configuração já concluída."). Isso é o que faz a tela se "desativar sozinha" depois que o primeiro (e único) usuário existir.
- `skip_before_action :authenticate_user!` (herdado de `ApplicationController`), já que não há usuário logado possível antes do primeiro cadastro.

## Formulário e criação do usuário

- Campos: email, senha, confirmação de senha — mesmo `User` e mesmas validações já existentes (`password_complexity`: mínimo de caracteres, 1 maiúscula, 1 caractere especial).
- Em caso de sucesso: cria o `User`, faz sign in automático (`sign_in(user)`) e redireciona para a raiz (dashboard).
- Em caso de erro de validação: re-renderiza o formulário com as mensagens de erro do Devise/Rails já padrão no restante da aplicação.

## Tela de login

- `app/views/devise/sessions/new.html.erb` (ou view equivalente do Devise) ganha um link condicional "Criar conta" (`new_setup_path` ou rota equivalente), visível **somente quando `User.count.zero?`**. O link desaparece sozinho assim que o usuário é criado, coerente com o comportamento da rota.

## `db:seed`

Continua existindo e funcionando exatamente como hoje (`db/seeds.rb`), sem alterações — é uma alternativa via terminal para o mesmo resultado, útil por exemplo em deploys automatizados.

## Testes

- Request specs para `SetupController`:
  - `GET /setup` e `POST /setup` funcionam normalmente quando não há usuário.
  - `POST /setup` com senha inválida (sem maiúscula/caractere especial) re-renderiza com erro, sem criar o usuário.
  - `POST /setup` com dados válidos cria o usuário, autentica automaticamente (sessão ativa) e redireciona para a raiz.
  - Quando já existe um usuário: `GET /setup` e `POST /setup` redirecionam para o login, sem alterar o `User.count`.
- Request/system spec da tela de login: o link "Criar conta" aparece quando `User.count.zero?` e não aparece quando já existe usuário.

## Fora de escopo

- Editar ou excluir a própria conta pela interface (não implementado; segue via console/seed se necessário).
- Qualquer forma de convidar ou criar usuários adicionais — o sistema continua limitado a um único usuário.
- Recuperação de senha esquecida por essa tela (já existe `:recoverable` do Devise, não é afetado por esta mudança).
