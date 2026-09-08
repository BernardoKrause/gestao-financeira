# Responsividade de Recorrências + Favicon — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Torna a tabela de Recorrências responsiva (padrão table→cards, mesmo usado em Categorias/Lançamentos/Histórico) e troca o favicon placeholder do Rails pela logo real da aplicação.

**Architecture:** Duas tarefas independentes, sem dependência entre si (podem ser executadas em qualquer ordem, inclusive em paralelo). Task 1 extrai um partial de linha (`_recurring_entry_row.html.erb`) seguindo exatamente o padrão já usado em `app/views/transactions/_transaction_row.html.erb`. Task 2 processa uma imagem fonte com `ffmpeg` para remover um fundo quadriculado falso (gravado nos pixels, não é transparência real) e produzir um ícone quadrado com transparência real, substituindo os arquivos estáticos em `public/`.

**Tech Stack:** Rails views (ERB) + Tailwind (já compilado no projeto), RSpec + Nokogiri para os testes de request, `ffmpeg` (já instalado no ambiente) para o processamento de imagem.

## Global Constraints

- Seguir exatamente o padrão de partial já estabelecido em `app/views/transactions/_transaction_row.html.erb` (locals `record:`/`format:`, branch `if format == :table` / `else`) — não inventar uma estrutura nova.
- `sr-only` para conteúdo escondido visualmente, nunca `hidden` (regra aprendida na Fase 2 — `hidden` também esconde de leitores de tela).
- Nenhuma dependência nova: `ffmpeg` já está disponível no ambiente, nenhuma gem/pacote novo é necessário para nenhuma das duas tasks.
- Specs em português (nomes de campos, textos de UI), código e nomes de arquivo em inglês — convenção já usada em todo o projeto.

---

### Task 1: Tabela de Recorrências responsiva (table→cards)

**Files:**
- Create: `app/views/recurring_entries/_recurring_entry_row.html.erb`
- Modify: `app/views/recurring_entries/index.html.erb`
- Test: `spec/requests/recurring_entries_spec.rb`

**Interfaces:**
- Consumes: `RecurringEntry#description`, `#day_of_month`, `#expense?` (enum `kind`), `#amount`, `#category` (→ `#name`), `#active?`, `#end_date` (nilável) — todos já existentes em `app/models/recurring_entry.rb`.
- Produces: partial `recurring_entry_row` renderizado com locals `entry:` (uma `RecurringEntry`) e `format:` (`:table` ou `:card`) — usado só por `index.html.erb`, nenhum outro arquivo depende disso.

- [ ] **Step 1: Escrever os testes de request que ainda vão falhar**

Adicionar ao final de `spec/requests/recurring_entries_spec.rb`, antes do `end` final da classe:

```ruby
  it "renders both a desktop table and a mobile card list for the same recurring entries" do
    create(:recurring_entry, category: category, user: user, description: "Aluguel")

    get recurring_entries_path

    expect(response.body).to include('data-testid="recurring-entries-table"')
    expect(response.body).to include('data-testid="recurring-entries-cards"')
    expect(response.body.scan("Aluguel").count).to eq(2)
  end

  it "omits the visible type, category, status and end date badges from the mobile card, keeping only day, description and amount (with screen-reader-only labels for the rest)" do
    entry = create(:recurring_entry, category: category, user: user, description: "Aluguel", kind: :expense, amount: 1500, day_of_month: 5, active: true)

    get recurring_entries_path

    doc = Nokogiri::HTML(response.body)
    cards = doc.at_css('[data-testid="recurring-entries-cards"]')

    expect(cards.text).to include("Aluguel")
    expect(cards.text).to include("Dia 5")
    expect(cards.text).to include(ActionController::Base.helpers.number_to_currency(1500, unit: "R$ "))
    expect(cards.css("span.rounded-full")).to be_empty

    sr_only_texts = cards.css("span.sr-only").map(&:text)
    expect(sr_only_texts).to include("Gasto")
    expect(sr_only_texts).to include("Categoria: #{category.name}")
    expect(sr_only_texts).to include("Status: Ativa")
    expect(sr_only_texts).to include("Até: Sem fim")
  end
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `bundle exec rspec spec/requests/recurring_entries_spec.rb -e "renders both a desktop table" -e "omits the visible type"`
Expected: FAIL — `data-testid="recurring-entries-table"` não existe ainda no HTML atual (é uma `<table>` sem esse atributo), e não há nenhum `span.sr-only` na página.

- [ ] **Step 3: Criar o partial `_recurring_entry_row.html.erb`**

Criar `app/views/recurring_entries/_recurring_entry_row.html.erb`:

```erb
<% if format == :table %>
  <tr>
    <td class="border px-3 py-2"><%= entry.description %></td>
    <td class="border px-3 py-2"><%= entry.day_of_month %></td>
    <td class="border px-3 py-2">
      <span class="rounded-full px-2 py-1 text-xs font-medium text-white <%= entry.expense? ? 'bg-red-600' : 'bg-green-600' %>">
        <%= entry.expense? ? "Gasto" : "Receita" %>
      </span>
    </td>
    <td class="border px-3 py-2 font-semibold <%= entry.expense? ? 'text-red-600' : 'text-green-600' %>">
      <%= number_to_currency(entry.amount, unit: "R$ ") %>
    </td>
    <td class="border px-3 py-2"><%= entry.category.name %></td>
    <td class="border px-3 py-2">
      <span class="rounded-full px-2 py-1 text-xs font-medium text-white <%= entry.active? ? 'bg-green-600' : 'bg-gray-500' %>">
        <%= entry.active? ? "Ativa" : "Inativa" %>
      </span>
    </td>
    <td class="border px-3 py-2"><%= entry.end_date ? entry.end_date.strftime("%d/%m/%Y") : "Sem fim" %></td>
    <td class="border px-3 py-2 text-right">
      <%= link_to "Editar", edit_recurring_entry_path(entry), class: "rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50" %>
      <%= link_to "Remover", recurring_entry_path(entry), data: { turbo_method: :delete, turbo_confirm: "Tem certeza?" }, class: "rounded border border-red-300 px-2 py-1 text-xs text-red-600 hover:bg-red-50" %>
    </td>
  </tr>
<% else %>
  <div class="rounded-lg border border-gray-200 bg-white p-4 text-sm">
    <div class="flex items-center justify-between gap-2">
      <span class="font-semibold text-gray-900">Dia <%= entry.day_of_month %></span>
      <span class="font-semibold <%= entry.expense? ? 'text-red-600' : 'text-green-600' %>">
        <%= number_to_currency(entry.amount, unit: "R$ ") %>
        <span class="sr-only"><%= entry.expense? ? "Gasto" : "Receita" %></span>
      </span>
    </div>
    <p class="mt-1 text-gray-700"><%= entry.description %></p>
    <span class="sr-only">Categoria: <%= entry.category.name %></span>
    <span class="sr-only">Status: <%= entry.active? ? "Ativa" : "Inativa" %></span>
    <span class="sr-only">Até: <%= entry.end_date ? entry.end_date.strftime("%d/%m/%Y") : "Sem fim" %></span>
    <div class="mt-3 flex gap-3">
      <%= link_to "Editar", edit_recurring_entry_path(entry), class: "rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50" %>
      <%= link_to "Remover", recurring_entry_path(entry), data: { turbo_method: :delete, turbo_confirm: "Tem certeza?" }, class: "rounded border border-red-300 px-2 py-1 text-xs text-red-600 hover:bg-red-50" %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 4: Reescrever `index.html.erb` para usar o partial e expor a tabela/cards**

Substituir todo o conteúdo de `app/views/recurring_entries/index.html.erb` por:

```erb
<h1 class="mb-4 text-2xl font-bold">Gastos e receitas fixas</h1>
<%= link_to "Nova recorrência", new_recurring_entry_path, class: "mb-4 inline-block rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>

<div class="grid gap-3 md:hidden" data-testid="recurring-entries-cards">
  <% @recurring_entries.each do |entry| %>
    <%= render "recurring_entry_row", entry: entry, format: :card %>
  <% end %>
</div>

<table class="hidden w-full bg-white text-sm md:table" data-testid="recurring-entries-table">
  <thead>
    <tr>
      <th class="border px-3 py-2 text-left">Descrição</th>
      <th class="border px-3 py-2 text-left">Dia</th>
      <th class="border px-3 py-2 text-left">Tipo</th>
      <th class="border px-3 py-2 text-left">Valor</th>
      <th class="border px-3 py-2 text-left">Categoria</th>
      <th class="border px-3 py-2 text-left">Status</th>
      <th class="border px-3 py-2 text-left">Até</th>
      <th class="border px-3 py-2 text-left"></th>
    </tr>
  </thead>
  <tbody>
    <% @recurring_entries.each do |entry| %>
      <%= render "recurring_entry_row", entry: entry, format: :table %>
    <% end %>
  </tbody>
</table>
```

- [ ] **Step 5: Rodar os testes novamente e confirmar que passam, mais o restante do arquivo**

Run: `bundle exec rspec spec/requests/recurring_entries_spec.rb`
Expected: PASS em todos os exemplos (os 2 novos + os já existentes, que não devem ter quebrado).

- [ ] **Step 6: Commit**

```bash
git add app/views/recurring_entries/_recurring_entry_row.html.erb app/views/recurring_entries/index.html.erb spec/requests/recurring_entries_spec.rb
git commit -m "feat: torna a tabela de Recorrências responsiva (table→cards)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0164cQGPn7wjWdG9JRdsKKKu"
```

---

### Task 2: Favicon real da aplicação

**Files:**
- Modify (binary, gerado): `public/icon.png`
- Delete: `public/icon.svg`
- Modify: `app/views/layouts/application.html.erb:18`
- Test: `spec/requests/favicon_spec.rb` (novo arquivo)

**Interfaces:**
- Consumes: `~/Downloads/logo-gestion.jpeg` (arquivo fonte fora do repositório, fornecido pelo usuário; apesar do nome mencionado ter sido `.png`, o arquivo real é `.jpeg`, 2816x1536, JPEG comum sem canal alfa — o fundo quadriculado visível está gravado nos pixels, não é transparência).
- Produces: nenhuma interface de código — é só um asset estático (`public/icon.png`) e uma linha a menos no layout. Nada mais depende disso.

- [ ] **Step 1: Escrever o teste de request que ainda vai falhar**

Criar `spec/requests/favicon_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Favicon", type: :request do
  it "links to the app icon and no longer references the removed placeholder SVG" do
    get root_path

    expect(response.body).to include('<link rel="icon" href="/icon.png" type="image/png">')
    expect(response.body).not_to include("icon.svg")
  end
end
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bundle exec rspec spec/requests/favicon_spec.rb`
Expected: FAIL — o layout hoje inclui `<link rel="icon" href="/icon.svg" ...>`, então `not_to include("icon.svg")` falha.

- [ ] **Step 3: Processar a imagem fonte com `ffmpeg`, gerando um PNG quadrado com transparência real**

Rodar, a partir da raiz do repositório (usar um diretório temporário para os arquivos intermediários):

```bash
mkdir -p /tmp/favicon-build
cd /tmp/favicon-build

# 1. Máscara de transparência por threshold de luminância (pixels escuros da marca
#    viram opacos, o fundo quadriculado claro vira transparente)
ffmpeg -y -i ~/Downloads/logo-gestion.jpeg \
  -vf "format=gray,geq=lum='if(lt(p(X\,Y)\,150)\,255\,0)'" \
  mask.png -loglevel error

# 2. Combina a máscara com a imagem original -> PNG com alfa real
ffmpeg -y -i ~/Downloads/logo-gestion.jpeg -i mask.png \
  -filter_complex "[0:v][1:v]alphamerge" \
  logo-transparent.png -loglevel error

# 3. Recorta para um quadrado centrado na marca (bounding box já medida:
#    x 774-2041, y 135-1418 na imagem 2816x1536 original) e redimensiona para 512x512
ffmpeg -y -i logo-transparent.png \
  -vf "crop=1400:1400:708:77,scale=512:512" \
  icon-512.png -loglevel error
```

- [ ] **Step 4: Verificar o resultado antes de substituir o arquivo do projeto**

Run: `sips -g pixelWidth -g pixelHeight -g hasAlpha /tmp/favicon-build/icon-512.png`
Expected:
```
pixelWidth: 512
pixelHeight: 512
hasAlpha: yes
```

- [ ] **Step 5: Substituir `public/icon.png` e remover `public/icon.svg`**

```bash
cp /tmp/favicon-build/icon-512.png public/icon.png
git rm public/icon.svg
```

- [ ] **Step 6: Remover a referência ao SVG do layout**

Em `app/views/layouts/application.html.erb`, remover a linha 18 (`<link rel="icon" href="/icon.svg" type="image/svg+xml">`), mantendo as linhas 17 e 19 (`icon.png` e `apple-touch-icon`) como estão:

```erb
    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="apple-touch-icon" href="/icon.png">
```

- [ ] **Step 7: Rodar o teste e confirmar que passa**

Run: `bundle exec rspec spec/requests/favicon_spec.rb`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add public/icon.png app/views/layouts/application.html.erb spec/requests/favicon_spec.rb
git commit -m "feat: substitui o favicon placeholder do Rails pela logo real da aplicação

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0164cQGPn7wjWdG9JRdsKKKu"
```
