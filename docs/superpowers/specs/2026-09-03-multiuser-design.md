# Multiusuário

## Contexto

O app é hoje single-user por construção: nenhum model (`Category`, `Transaction`,
`RecurringEntry`, `Setting`) tem `user_id`, `Setting` é um singleton global
(`Setting.instance` via `first_or_create!`), e `SetupController` só permite
criar a *primeira* conta — depois disso, `redirect_if_setup_complete` bloqueia
a rota de cadastro (`User.exists?` → redirect pro login). Todas as queries nos
controllers e em 3 views são globais, sem escopo de dono.

Objetivo: virar multiusuário de verdade, com cadastro público e isolamento de
dados entre contas.

## Decisões

- **Categorias são privadas por usuário.** Cada conta tem sua própria lista,
  isolada das outras.
- **Cadastro é público**, via rota padrão do Devise (`:registerable`).
- **Seed padrão no cadastro**: toda conta nova recebe as mesmas 13 categorias
  que o app já usa hoje — despesas: Aluguel, Assinatura, Cartão de Crédito,
  Contas de Casa, Esporte, Estética, Lanchonete/Restaurante, Mercado, Padaria,
  Saúde; receitas: Renda Extra, Salário, Vendas.
- **Migração de dados existentes**: hoje existe exatamente 1 usuário no banco;
  todo dado existente (categorias, transações, recorrências, setting) é
  atribuído a esse usuário no backfill da migration.

## Modelo de dados

Adicionar `user_id` (bigint, not null, FK) em `categories`, `transactions`,
`recurring_entries`, `settings`. Migration em duas etapas: coluna nullable →
backfill para o único usuário existente → `change_column_null` para `false` +
`add_foreign_key`.

- `User`: ganha `has_many :categories, :transactions, :recurring_entries,
  dependent: :destroy` e `has_one :setting, dependent: :destroy`. Ganha
  `:registerable` no `devise :...`.
- `Category`, `Transaction`, `RecurringEntry`, `Setting`: ganham
  `belongs_to :user`.
- `Setting.instance` (singleton global) é removido. É substituído por
  `current_user.setting`, sempre presente porque é criado no cadastro (ver
  Onboarding). Não precisa mais de `first_or_create!` em lugar nenhum.

## Onboarding no cadastro

Novo serviço `UserOnboarding.call(user)` (mesmo padrão de classe que
`RecurringEntryGenerator.call`, já existente no código), chamado em um
`after_create_commit :onboard!` no `User`:

- cria a `Setting` do usuário (`initial_balance: 0`)
- cria as 13 categorias padrão listadas acima

## Cadastro público

- `SetupController`, `app/views/setup/` e a rota `/setup` são removidos —
  inclusive o gate `redirect_if_setup_complete`, que não faz mais sentido.
- View `devise/registrations/new.html.erb` estilizada reaproveitando o layout
  do form de setup atual (mesmos campos: email, senha, confirmação de senha).
- Comportamento pós-cadastro (login automático, redirect pra dashboard) é o
  padrão do Devise com `root_path` já apontando pra `dashboard#index` — não
  precisa de controller customizado.
- Escopo explicitamente fora deste trabalho: telas de edição/cancelamento de
  conta (`devise/registrations#edit/update/destroy`). Ficam com o
  comportamento padrão do Devise, sem estilização, até serem pedidas.

## Isolamento de dados

Toda query global vira escopada em `current_user`:

- `TransactionsController`, `CategoriesController`, `RecurringEntriesController`:
  `set_*` e `index` passam a usar `current_user.transactions` /
  `.categories` / `.recurring_entries` em vez das classes direto. Isso fecha
  a falha de um usuário acessar/editar registro de outro pelo ID (IDOR).
- `DashboardData` concern: `@setting = current_user.setting`; queries de
  `Category`/`Transaction` (incluindo a lista de meses do filtro de
  histórico) passam a ser escopadas em `current_user`.
- Views com query direta (`app/views/dashboard/index.html.erb`,
  `app/views/transactions/_form.html.erb`,
  `app/views/recurring_entries/_form.html.erb`): trocam `Category.order(:name)`
  / `Category.expense.order(:name)` / `Category.income.order(:name)` por
  `current_user.categories.order(:name)` (com o scope de kind aplicado do
  mesmo jeito).
- `RecurringEntryGenerator`: continua rodando globalmente — um único cron
  processa as recorrências de todos os usuários de uma vez, sem precisar
  iterar por usuário. Só precisa setar `user: entry.user` explicitamente ao
  criar a `Transaction` gerada, já que o model agora exige `user_id`.

## Testes

- Factories (`categories`, `transactions`, `recurring_entries`, `settings`)
  ganham associação `user`.
- `spec/requests/setup_spec.rb` é substituído por specs de cadastro via
  Devise (`devise/registrations`).
- Cada controller de recurso (`transactions`, `categories`,
  `recurring_entries`) ganha pelo menos um teste de isolamento: usuário A não
  enxerga nem consegue editar/destruir registro de usuário B.
- `spec/services/recurring_entry_generator_spec.rb` e
  `spec/jobs/generate_recurring_transactions_job_spec.rb` são ajustados para
  múltiplos usuários com recorrências ativas simultâneas.

## Fora de escopo

- Tela de edição de `initial_balance`/Setting (não existe hoje, este trabalho
  não introduz uma).
- Convite/aprovação de novos usuários — cadastro é público e imediato.
- Compartilhamento de dados entre usuários (ex.: conta familiar).
