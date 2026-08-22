# Gestão Financeira — Design (v1)

Data: 2026-08-22

## Objetivo

Aplicação pessoal de gestão financeira (uso único, do Bernardo) para:

- Registrar gastos fixos (recorrentes mensais) e gastos do dia a dia (avulsos).
- Registrar receitas fixas (ex: salário) e receitas avulsas (ex: freela).
- Prever o caixa do mês (saldo atual + previsão de entradas/saídas restantes).
- Controlar múltiplas contas/cartões separadamente.

## Stack

- **Ruby on Rails** (versão estável mais recente, 8.x), monolito server-rendered com **Hotwire (Turbo + Stimulus)**. Sem API/SPA separada.
- **PostgreSQL** como banco de dados.
- **Devise** para autenticação — sem cadastro público; usuário único criado via seed/console.
  - Validação de senha customizada, além do padrão do Devise: mínimo de caracteres, pelo menos uma letra maiúscula e pelo menos um caractere especial.
- Valores monetários em colunas `decimal` (não `float`). Moeda única (BRL), sem suporte multi-moeda.
- Deploy recomendado: Render (Postgres + web service gratuito/barato), mas sem acoplamento forte — pode trocar de provedor sem mudanças de código.

## Modelagem de dados

- **User** (Devise) — dono de tudo, único usuário do sistema.
- **Account** — conta ou cartão.
  - `name`, `account_type` (corrente | poupança | cartão de crédito | dinheiro), `initial_balance`.
  - Cartão de crédito é tratado como conta simples (gasto impacta na hora); sem lógica de fatura/fechamento nesta versão.
- **Category** — categoria de gasto ou receita.
  - `name`, `kind` (expense | income), cor opcional (uso futuro em gráficos).
- **RecurringEntry** — molde de gasto ou receita fixa/recorrente.
  - `description`, `amount`, `kind` (expense | income), `account`, `category`, `day_of_month`, `active`, `start_date`, `end_date` (opcional).
  - Gera automaticamente uma `Transaction` todo mês (ver seção de geração automática).
- **Transaction** — lançamento efetivo (fixo gerado ou avulso).
  - `description`, `amount`, `date`, `kind` (expense | income), `account`, `category`, `recurring_entry` (opcional — presente quando a transação veio de um `RecurringEntry`).

### Regras

- Editar um `RecurringEntry` (ex: valor do aluguel mudou) não altera lançamentos já gerados, só os futuros.
- Desativar (`active = false`) um `RecurringEntry` interrompe a geração de novos lançamentos, mas preserva o histórico.
- Um `RecurringEntry` nunca gera mais de uma `Transaction` no mesmo mês.

## Geração automática dos lançamentos fixos

- Job diário (recorrente, via Solid Queue ou `whenever`/cron) que:
  1. Busca `RecurringEntry` ativos cujo `day_of_month` já chegou no mês corrente.
  2. Para cada um, verifica se já existe uma `Transaction` gerada a partir dele neste mês; se não, cria.
- Idempotente: rodar o job mais de uma vez no mesmo dia não duplica lançamentos.

## Dashboard / Previsão de caixa do mês

Tela principal, para o mês corrente:

- Saldo atual por conta (`initial_balance` + transações lançadas até hoje).
- Previsto até o fim do mês, por conta e total consolidado:
  `saldo atual + receitas fixas restantes do mês + receitas avulsas já lançadas − gastos fixos restantes do mês − gastos avulsos já lançados`.
- Lista de lançamentos do mês (fixos e avulsos), com filtro por conta e por categoria.

## Testes

- RSpec.
- Testes de model: validações, cálculo de saldo e previsão de caixa, geração de lançamentos fixos (idempotência, respeito a `active`/`end_date`).
- Testes de request/system: fluxo de criar conta, criar categoria, criar gasto/receita avulsa, criar `RecurringEntry`, visualizar dashboard.

## Fora de escopo (nesta versão)

Sugestões de melhoria futura ficam a critério do Bernardo, a serem propostas e aprovadas em uma próxima spec. Não fazem parte desta versão inicial:

- Lógica de fatura de cartão de crédito (fechamento, vencimento, fatura acumulada).
- Compras parceladas.
- Orçamento por categoria com alertas.
- Metas de economia.
- Gráficos/relatórios avançados.
- Importação de extrato (CSV/OFX).
- Multi-usuário / multi-moeda.
