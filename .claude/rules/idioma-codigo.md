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

## Nomes legados
O `CLAUDE.md`, `docs/` e as outras rules ainda citam nomes em português (`Transacao.nova(...)`, `NegocioException`, `eventos_processados`). Trate-os como o conceito, e implemente com o equivalente em inglês:

| Português | Inglês |
|---|---|
| Transacao / TransacaoRegistrada | Transaction / TransactionRegistered |
| Conta | Account |
| Orcamento | Budget |
| Categoria / NAO_CLASSIFICADA | Category / UNCLASSIFIED |
| Valor | Amount |
| Estorno / estornar | Reversal / reverse |
| NegocioException | BusinessException |
| ServicoIndisponivelException | ServiceUnavailableException |
| eventos_processados | processed_events |
| `financas.transacoes.registradas` | `finance.transactions.registered` |

- Os nomes dos módulos (`conta-service`, ...) e os pacotes base dos serviços (`br.com.finance.conta`, ...) ficam como estão até uma migração dedicada. Os subpacotes `domain`, `application` e `infra` já estão em inglês.
- Termo fora da tabela: use o termo usual do domínio financeiro em inglês e mantenha o mesmo nome em todos os serviços.
