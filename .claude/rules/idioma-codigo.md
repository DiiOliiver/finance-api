# Idioma do código

Complementa o `CLAUDE.md`. Vale para todo código e configuração do repositório.

## Regra
- Código em **inglês**: classes, records, interfaces, enums e seus valores, métodos, variáveis, parâmetros, constantes, pacotes novos, nomes de arquivo, chaves de configuração, métricas, filas, routing keys, coleções e recursos REST.
- Strings técnicas também em inglês: mensagens de log, mensagens de exceção e `title`/`detail` do Problem Details.
- **Comentários em português**: comentários de linha, de bloco e Javadoc.

```java
// Estornos não apagam o lançamento original, apenas geram um lançamento inverso.
public Transaction reverse(Clock clock) {
    if (isReversed()) {
        throw new BusinessException("Transaction already reversed");
    }
    ...
}
```

## Glossário do domínio
O texto da documentação é em português, e os nomes no código são em inglês. O `CLAUDE.md`, os `docs/` e as rules já usam os nomes em inglês. Para traduzir um termo do texto para o código, use sempre o mesmo nome:

| Português (texto) | Inglês (código) |
|---|---|
| Transação / transação registrada | `Transaction` / `TransactionRegistered` |
| Conta / saldo | `Account` / `balance` |
| Orçamento / meta | `Budget` / `Goal` |
| Categoria / não classificada | `Category` / `UNCLASSIFIED` |
| Valor / moeda | `Amount` / `Currency` |
| Comprovante | `Receipt` |
| Estorno / estornar | `Reversal` / `reverse` |
| Receita / despesa | `INCOME` / `EXPENSE` |
| Exceção de negócio | `BusinessException` |
| Serviço indisponível | `ServiceUnavailableException` |
| Eventos processados (idempotência) | `processed_events` |
| Usuário | `userId` |

- Os nomes dos módulos (`conta-service`, `financas-eventos`...) e os pacotes base dos serviços (`br.com.finance.conta`...) ficam como estão até uma migração dedicada; o mesmo vale para as classes `*ServiceApplication` geradas pelo Initializr. Os subpacotes `domain`, `application` e `infra` já estão em inglês.
- No nome de uma fila, o prefixo é o serviço consumidor e mantém o nome do módulo: `orcamento.transaction-registered`.
- Termo fora da tabela: use o termo usual do domínio financeiro em inglês e mantenha o mesmo nome em todos os serviços.
