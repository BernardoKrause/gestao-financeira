# Gestão Financeira

Aplicação pessoal de gestão financeira em Ruby on Rails: contas, categorias,
gastos/receitas fixas (recorrentes) e avulsas, e um painel com saldo atual e
previsto do mês.

## Setup inicial (só na primeira vez, ou depois de `git pull` com migrations novas)

    bundle install
    bin/rails db:create db:migrate

## Criar o usuário

Suba a aplicação (`bin/dev`) e acesse http://localhost:3000/users/sign_up — o cadastro é
público e fica sempre disponível (não é mais restrito ao primeiro usuário do sistema).

Alternativa via terminal (útil em deploys automatizados), com o mesmo resultado:

    SEED_USER_EMAIL=seu@email.com SEED_USER_PASSWORD='SenhaForte#1' bin/rails db:seed

A senha precisa ter ao menos uma letra maiúscula e um caractere especial.

## Rodar localmente (dia a dia)

    bin/dev

E acessar http://localhost:3000 — a raiz é o Hub; clique em "Gestão Financeira" pra
entrar (vai pedir login com o usuário criado acima).

O PostgreSQL roda em background como serviço do Homebrew (`postgresql@17`) e
inicia sozinho no login da máquina — não precisa subir nada manualmente. Se
quiser conferir se está no ar: `pg_isready` (deve responder `accepting
connections`). Se não estiver: `brew services start postgresql@17`.

## Rodar os testes

    bundle exec rspec

## Geração automática de lançamentos fixos

Um job diário (`GenerateRecurringTransactionsJob`, agendado em
`config/recurring.yml` via Solid Queue) gera a transação do mês para cada
gasto/receita fixa ativa, no dia configurado (`day_of_month`). Rodar
manualmente:

    bin/rails runner "RecurringEntryGenerator.call"
