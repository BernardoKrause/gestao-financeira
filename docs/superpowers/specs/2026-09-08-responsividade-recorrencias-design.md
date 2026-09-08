# Responsividade — tabela de Recorrências

## Contexto

Fase 3 do esforço de responsividade mobile (ver [[gestao-financeira-responsividade]]). As fases anteriores já aplicaram o padrão table→cards em Categorias, Lançamentos e Histórico (dashboard). Recorrências (`app/views/recurring_entries/index.html.erb`) é a última tabela pendente do effort-map original, e a mais densa: 7 colunas (Descrição, Dia, Tipo, Valor, Categoria, Status, Até) + ações.

Escopo desta rodada: **só o `index`** (a tabela). O formulário (`_form.html.erb`) e o `show` ficam fora, como itens separados e menores do effort-map.

## Padrão de card: reduzido + sr-only

Lançamentos e Histórico (as tabelas mais densas até agora) mostram no card só **Data + Descrição + Valor**, jogando o resto (Tipo, Categoria, Status) para `sr-only`. Recorrências segue a mesma lógica de densidade, usando **Dia** (dia do mês em que a recorrência ocorre) como o campo temporal equivalente à Data:

- **Visível no card:** Descrição, Dia, Valor (com a cor vermelho/verde de gasto/receita, igual à tabela)
- **`sr-only` no card:** Tipo (Gasto/Receita), Categoria, Status (Ativa/Inativa), Até

## Implementação

Extrair `app/views/recurring_entries/_recurring_entry_row.html.erb`, seguindo exatamente o padrão de `app/views/transactions/_transaction_row.html.erb` (`if format == :table` / `else` card), recebendo `entry:`/`format:` como locals.

Em `index.html.erb`:
- `<table>` ganha `hidden md:table` e `data-testid="recurring-entries-table"`
- Novo `<div class="grid gap-3 md:hidden" data-testid="recurring-entries-cards">` renderiza o mesmo partial com `format: :card`
- Ambos renderizados no servidor a cada request, sem JS (mesmo padrão das fases anteriores)

Ações (Editar/Remover) mantidas nos dois formatos, como em todas as tabelas anteriores.

## Testes

`spec/requests/recurring_entries_spec.rb` ganha uma cobertura análoga à de `transactions_spec.rb`:
- Resposta inclui `data-testid="recurring-entries-table"` e `data-testid="recurring-entries-cards"`
- Dentro do bloco de cards: os badges visuais de Tipo e Status (`span.rounded-full`) **não** aparecem, mas o texto correspondente (Gasto/Receita, Ativa/Inativa) existe como `sr-only`
- Categoria e Até (data de término) não aparecem como texto visível no card; também viram `sr-only`, seguindo o mesmo tratamento de Tipo e Status

## Fora de escopo

- `_form.html.erb` e `show.html.erb` de Recorrências (itens separados do effort-map, menores)
- Qualquer mudança de comportamento/dado — é puramente uma mudança de apresentação
