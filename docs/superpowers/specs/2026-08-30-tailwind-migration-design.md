# Migração de front-end: Bootstrap → Tailwind

## Contexto

O projeto usa Bootstrap 5.3.3 via CDN (só CSS, sem JS do Bootstrap — nenhum
`data-bs-*` é usado; os toggles de campo do quick entry já são feitos com
`:has()` puro). 17 templates `.erb`, ~491 linhas de view, um único arquivo de
CSS customizado (`app/assets/stylesheets/application.css`, 68 linhas) que usa
`var(--bs-danger)`/`var(--bs-success)`.

Vamos trocar por Tailwind. Há novas features previstas que vão substituir boa
parte das telas atuais (dashboard, tabelas, forms), então esta migração é
deliberadamente rasa: o objetivo é sair do Bootstrap e ficar funcional, não
preservar aparência pixel-a-pixel.

## Decisões

- **Integração**: gem `tailwindcss-rails` (CLI standalone, integra com
  Propshaft + `bin/dev`). Não usar Play CDN (não serve pra produção).
- **Escopo visual**: sem paridade. Layout shell (navbar, container, flash em
  `application.html.erb`) migra com cuidado por persistir em todas as
  páginas. O resto (dashboard, forms de categorias/transações/recorrências,
  tabelas, devise/setup) migra "no básico" — troca de classes por utilitários
  equivalentes, sem replicar striping de tabela, sombra de card, badges
  arredondados etc.
- **CSS customizado**: as duas referências a variáveis do Bootstrap viram
  cores fixas do Tailwind (`red-600`/`green-600`). A lógica `:has()` dos
  toggles é mantida como está.
- **Sem abstrações novas**: nenhum partial/componente reutilizável novo é
  criado nesta migração — é uma passagem de troca de classes, não um design
  system.

## Fora de escopo

- Refresh visual, novos componentes, dark mode, design system.
- Reescrever tabelas/cards com novo layout — só troca de classes.

## Plano de implementação

Delegado ao writing-plans a partir deste spec.
