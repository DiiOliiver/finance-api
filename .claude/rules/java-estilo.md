---
paths:
  - "**/*.java"
---
# Estilo Java

Complementa o `CLAUDE.md`. Vale para todo código Java do repositório.

## Nomes
- Classes e records: `PascalCase`. Métodos e variáveis: `camelCase`. Constantes: `UPPER_SNAKE_CASE`.
- Métodos booleanos com prefixo `is`/`has`: `isActive()`, `hasBalance()`, `isReversed()`.
- Não abrevie: `transaction`, não `trx` ou `t`. Exceção: variáveis de laço e lambdas curtas.

## Recursos do Java 25
- Use `sealed interface` para hierarquias fechadas (ex.: tipos de evento, resultado de uma operação).
- Use `switch` com pattern matching sobre tipos selados, **sem** `default`, para o compilador acusar casos faltando.
- Use `var` só quando o tipo está óbvio na mesma linha.
- Use text blocks (`"""`) para JSON, prompts e consultas longas.
- Não use Lombok em nenhuma camada: `record` e construtores resolvem.

## Imutabilidade e nulos
- Campos `final` por padrão. Nada de estado estático mutável.
- `Optional` só como retorno de método. Nunca como campo ou parâmetro.
- Coleções nunca retornam `null`: devolva lista vazia. Exponha coleções com `List.copyOf(...)`.
- Valide parâmetros obrigatórios com `Objects.requireNonNull` nos construtores.

## Dinheiro e datas
- `BigDecimal` sempre com `setScale(2, RoundingMode.HALF_EVEN)` ao final de cálculos.
- Compare valores com `compareTo`, nunca com `equals` (`10.0` ≠ `10.00` no `equals`).
- Crie `BigDecimal` a partir de `String` ou `long`, nunca de `double` (`new BigDecimal("59.90")`).
- Momento exato: `Instant` (UTC). Data sem hora: `LocalDate`. Mês de competência: `YearMonth`.
- Nunca chame `Instant.now()` / `LocalDate.now()` direto no domínio ou nos casos de uso: receba um `java.time.Clock`.

## Exceções
- Não capture `Exception` ou `Throwable` genéricos, exceto em fallbacks e no handler global.
- Nunca engula exceção (`catch` vazio ou só com log sem relançar, quando a falha importa).
- Ao relançar, mantenha a causa original: `new XException("mensagem", causa)`.
- Domínio usa apenas exceções não checadas.

## Comentários
- Comente o **porquê**, não o **o quê**.
- Javadoc apenas em portas (`*UseCase`, `*Port`) e contratos de evento.
- Não deixe código comentado nem `TODO` sem contexto.
