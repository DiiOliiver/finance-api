---
paths:
  - "**/infra/web/**"
  - "api-gateway/**"
---
# API REST

Complementa o `CLAUDE.md` (Problem Details já é obrigatório lá).

## Recursos e URLs
- Recursos no plural, em inglês, minúsculas e kebab-case: `/accounts`, `/transactions`, `/receipts`.
- O gateway expõe com prefixo `/api` (`/api/transactions`). Cada serviço expõe sem o prefixo (`/transactions`).
- Ações que não são CRUD viram sub-recurso com substantivo: `POST /transactions/{id}/reversal`, `POST /receipts/{id}/confirm`.
- IDs no caminho são UUID. Valide o formato e devolva 400 se inválido.

## Métodos e status
| Situação | Resposta |
|---|---|
| Criação | `POST` → `201 Created` + header `Location` + corpo |
| Consulta | `GET` → `200`; não encontrado → `404` |
| Atualização completa / parcial | `PUT` / `PATCH` → `200` |
| Remoção | `DELETE` → `204` (transações não são removidas) |
| Entrada inválida | `400` |
| Conflito de estado (ex.: já estornada) | `409` |
| Regra de negócio violada | `422` |
| Dependência indisponível (circuito aberto) | `503` + header `Retry-After` |

## Contratos
- Request e response são `record` próprios da camada web (`*Request`, `*HttpResponse`). Nunca exponha entidade de domínio nem `*Document`.
- Bean Validation (`@NotNull`, `@Positive`, `@Size`...) só nos `*Request`. O domínio continua validando a si mesmo.
- JSON em `camelCase`. Datas em ISO-8601 UTC (`2026-10-21T04:13:00Z`). Valores monetários como `amount` + `currency`.
- Configure o Jackson com `USE_BIG_DECIMAL_FOR_FLOATS` para não perder precisão.

## Listagens
- Paginação com `page` (base 0) e `size` (padrão 20, máximo 100), mais `sort`.
- Resposta com `conteudo`, `pagina`, `tamanho`, `totalElementos`, `totalPaginas`.
- Nunca devolva listas sem limite.

## Idempotência
- `POST` que cria recurso financeiro aceita o header `Idempotency-Key`. A mesma chave devolve a mesma resposta, sem criar duplicado.

## Documentação
- Use `springdoc-openapi`. Anote cada endpoint com `@Operation` e os `@ApiResponse` de erro relevantes.
- Mantenha o resumo do `@Operation` em inglês e curto.

## Segurança
- Nunca devolva stack trace, nome de classe ou mensagem interna no corpo de erro.
- O `userId` vem do token validado no gateway. Nunca aceite `userId` no corpo ou na query.
