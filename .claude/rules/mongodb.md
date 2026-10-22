---
paths:
  - "**/infra/persistence/**"
---
# MongoDB

Complementa o `CLAUDE.md` (UUID standard, `Decimal128`, Document ≠ entidade e Mongock já estão lá).

## Documentos
- Nome da coleção explícito, em inglês, no plural e em `snake_case`: `@Document("transactions")`, `@Document("processed_events")`.
- Campos em `camelCase`. Enums gravados como `String`, nunca pelo ordinal.
- Datas como `Instant`. Não use `java.util.Date`.
- Não use `@DBRef`: referencie outros agregados só pelo UUID.
- Agregados alterados concorrentemente (saldo, orçamento) usam `@Version` (lock otimista). Ao receber `OptimisticLockingFailureException`, releia e tente de novo.

## Repositórios
- A interface do Spring Data é package-private e usada **só** pelo `*RepositoryAdapter` do mesmo pacote.
- Para atualizações parciais ou contadores, use `MongoTemplate` com `Update` atômico (`$set`, `$inc`) em vez de ler, alterar e salvar o documento inteiro.
- Use projeções quando a consulta não precisa do documento inteiro.

## Consultas
- Toda consulta de dados do usuário filtra por `usuarioId`.
- Nada de `findAll()` sem filtro e sem paginação.
- Toda consulta nova precisa de índice que a atenda. Confira com `explain()` se houver dúvida.

## Índices (via Mongock)
- Índice composto seguindo a consulta principal: igualdade primeiro, depois ordenação (ex.: `{usuarioId: 1, data: -1}`).
- `eventos_processados.eventId` com índice **único**.
- Índice TTL para dados temporários: `outbox` já enviada e `eventos_processados` (ex.: 30 dias).
- Changesets nunca são editados depois de aplicados: crie um novo.

## Transações
- Use transação Mongo só para gravar o agregado + `outbox` juntos.
- Nada de chamada externa dentro da transação.
