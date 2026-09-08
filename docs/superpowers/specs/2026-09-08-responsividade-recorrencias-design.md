# Responsividade — tabela de Recorrências (+ favicon)

Este documento cobre dois itens sem relação entre si, agrupados a pedido do usuário: responsividade da tabela de Recorrências e troca do favicon da aplicação (seção ao final).

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

---

# Favicon da aplicação

Item não relacionado à responsividade, incluído aqui a pedido do usuário.

## Contexto

A aplicação hoje usa os ícones placeholder padrão gerados pelo `rails new`: `public/icon.png` (o logo genérico do Rails, 512x512) e `public/icon.svg` (um círculo vermelho liso). `app/views/layouts/application.html.erb` referencia os dois via `<link rel="icon">` mais um `<link rel="apple-touch-icon">` apontando para o PNG.

O usuário forneceu uma logo real em `~/Downloads/logo-gestion.jpeg` (apesar do nome mencionado ser `.png`, o arquivo é um `.jpeg`, 2816x1536). É uma marca em cinza-escuro/azulado sobre um fundo xadrez — esse xadrez está **gravado nos pixels do JPEG** (o arquivo não tem canal alfa; provavelmente é um screenshot de uma visualização de PNG transparente), então não pode ser usado diretamente como favicon sem processamento.

## Processamento da imagem

Validado com `ffmpeg` (já disponível no ambiente, sem dependências novas):

1. Gerar uma máscara de transparência por threshold de luminância — pixels escuros (a marca) viram opacos, pixels claros (o xadrez) viram transparentes:
   `ffmpeg -i logo-gestion.jpeg -vf "format=gray,geq=lum='if(lt(p(X\,Y)\,150)\,255\,0)'" mask.png`
2. Combinar a máscara com a imagem original via `alphamerge`, produzindo um PNG com transparência real:
   `ffmpeg -i logo-gestion.jpeg -i mask.png -filter_complex "[0:v][1:v]alphamerge" logo-transparent.png`
3. Recortar (crop) a região transparente sobrando ao redor da marca e redimensionar para um quadrado 512x512 (o ícone fica dentro de um círculo, então cabe naturalmente num quadrado com pequena margem).

O threshold (150) foi validado visualmente nesta sessão — pixels de fundo caem para alfa 0, o traço escuro da marca fica com alfa 255, sem halo/serrilhado visível.

## Arquivos alterados

- `public/icon.png` — substituído pela logo processada (512x512, com transparência)
- `public/icon.svg` — removido (não temos versão vetorial real da logo; manter o círculo vermelho placeholder não faz sentido, e gerar um SVG fake a partir de um raster não traz benefício sobre servir só o PNG)
- `app/views/layouts/application.html.erb` — remove a linha do `<link rel="icon" href="/icon.svg" ...>` (linha 18); mantém o `<link rel="icon" href="/icon.png" ...>` e o `apple-touch-icon"`, ambos já apontando para `/icon.png`

## Fora de escopo

- Qualquer redesenho da logo em si (cores, traço) — só reaproveitamento do arquivo fornecido
- Favicons em outros tamanhos/formatos (ex: `.ico` multi-resolução, manifest.json de PWA) — o app não tem PWA hoje, YAGNI
