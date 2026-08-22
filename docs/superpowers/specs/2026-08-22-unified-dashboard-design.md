# Dashboard Unificado (lançamento rápido) — Design

Data: 2026-08-22

## Objetivo

Unificar o uso do dia a dia (lançar gastos/receitas — fixos ou avulsos — ver histórico do mês e o caixa) numa única tela: o dashboard. Hoje, criar um lançamento exige navegar para `/transactions/new` ou `/recurring_entries/new`; a ideia é permitir lançar direto do dashboard, sem sair da página.

## Escopo

- **Dentro do escopo:** o dashboard ganha dois botões de lançamento rápido (Gasto/Receita), formulário inline, totais mensais, geração imediata do lançamento quando marcado como fixo.
- **Fora do escopo:** as páginas de Contas, Categorias, Transações e Recorrências continuam existindo exatamente como hoje (cadastro/edição/exclusão) — usadas com pouca frequência, não fazem parte desta mudança. Nenhuma delas é removida da navegação.

## Dashboard: dados novos

Além do que já existe (saldo atual e previsto por conta, total consolidado, lista de lançamentos do mês), o dashboard passa a mostrar, para o mês corrente:

- Total de receitas do mês (soma de `Transaction` com `kind: income` datadas no mês corrente).
- Total de gastos do mês (soma de `Transaction` com `kind: expense` datadas no mês corrente).

O saldo atual/previsto por conta continua calculado exatamente como hoje (acumulado desde `initial_balance`) — não muda de significado, só ganha esse resumo mensal ao lado.

## Lançamento rápido

Dois botões no dashboard: **Gasto** (vermelho) e **Receita** (verde). Clicar em um expande, na mesma tela (sem navegar, sem recarregar a página), um formulário compacto — usando `<details>/<summary>` nativo do HTML, sem JavaScript.

**Campos do formulário:**
- Descrição, valor, conta (`Account`), categoria (`Category` — a lista já vem filtrada pelo `kind` correspondente: só categorias de despesa no formulário de Gasto, só de receita no de Receita).
- Checkbox **"Fixo (recorrente)"**. Alterna, via CSS puro (sem JavaScript), entre dois campos mutuamente exclusivos:
  - Desmarcado (padrão): campo **Data** (default: hoje) — cria uma `Transaction` avulsa.
  - Marcado: campo **Dia do mês** (1-31) — cria um `RecurringEntry` (com `start_date` igual a hoje, sem `end_date`; esses dois campos não aparecem no formulário rápido — quem precisar ajustá-los usa a tela de Recorrências, que continua existindo).

**Geração imediata:** ao marcar "fixo" e salvar, além de criar o `RecurringEntry`, o sistema roda `RecurringEntryGenerator.call` na hora — se o dia do mês já tiver passado ou chegado hoje, o lançamento deste mês aparece imediatamente no histórico, sem esperar o job diário agendado (`config/recurring.yml`). Isso é consistente com a regra que já existe hoje: um `RecurringEntry` criado no meio do mês com `day_of_month` já passado gera o lançamento retroativo ao dia configurado assim que o gerador roda — só estamos rodando o gerador na hora em vez de esperar o próximo dia.

**Ao salvar com sucesso:** volta para o dashboard (`root_path`), com o histórico e os totais já refletindo o novo lançamento.

**Ao salvar com erro de validação:** volta para o dashboard com o formulário correspondente (Gasto ou Receita) já aberto, mostrando os erros — sem perder o contexto da tela.

## Arquitetura

- **`QuickEntriesController#create`** (rota `POST /quick_entries`) — action única que recebe `kind` (expense/income, via campo oculto em cada formulário), `fixed` (checkbox), e os campos comuns (`description`, `amount`, `account_id`, `category_id`) mais um dos dois campos condicionais (`date` ou `day_of_month`, dependendo de `fixed`). Internamente cria uma `Transaction` ou um `RecurringEntry` reaproveitando os models e validações que já existem — nenhuma regra de negócio nova nos models.
- **Dados do dashboard reaproveitados:** a lógica que hoje vive em `DashboardController#index` (montar `@accounts`, `@total_current_balance`, `@total_projected_balance`, `@transactions`, e os novos totais mensais) é extraída para um método compartilhado, usado tanto por `DashboardController#index` quanto por `QuickEntriesController#create` no caminho de erro (que precisa re-renderizar a view do dashboard completa, não só o formulário).
- **Sem lançamentos duplicados:** o formulário rápido não substitui `TransactionsController`/`RecurringEntriesController` — são pontos de entrada diferentes para os mesmos models, cada um com seu próprio propósito (rápido vs. completo/edição).

## Estilo visual

- Botão "Gasto": vermelho sólido.
- Botão "Receita": verde sólido.
- Sem bibliotecas ou dependências novas — CSS puro, seguindo o mesmo arquivo (`app/assets/stylesheets/application.css`) já usado no resto da aplicação.

## Testes

- Request specs para `QuickEntriesController#create`:
  - Cria uma `Transaction` avulsa (gasto e receita) com sucesso e redireciona para `root_path`.
  - Cria um `RecurringEntry` fixo (gasto e receita) com sucesso, confirma que `RecurringEntryGenerator` roda imediatamente e que a `Transaction` deste mês já existe após o request.
  - Erro de validação (ex: valor zero) não cria nada, re-renderiza o dashboard com status `422` e com o formulário correspondente marcado para abrir.
- Ajustar/estender `spec/requests/dashboard_spec.rb` se necessário para cobrir os novos totais mensais.

## Fora de escopo (nesta versão)

- Editar ou excluir lançamentos direto do dashboard (continua via as páginas de Transações/Recorrências).
- Qualquer mudança no significado de "saldo atual" (continua acumulado, não reseta por mês) — só o resumo mensal é novo.
- Compras parceladas, orçamento por categoria, gráficos — já estavam fora de escopo desde a spec original e continuam fora.
