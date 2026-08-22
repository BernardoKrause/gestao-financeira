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
