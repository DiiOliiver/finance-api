## Tarefa

<!-- Código e link da tarefa no quadro do Notion. Ex.: [E2 · T1 · Domínio de conta](https://app.notion.com/p/...) -->

## O que mudou

<!-- Resumo em tópicos: o que foi feito e por quê. Cite serviços, eventos ou contratos afetados. -->

-

## Como testar

<!-- Comandos e passos para validar a mudança. -->

```bash
./mvnw -pl <servico> verify
```

## Checklist

- [ ] Branch e commits no padrão (`<tipo>/<tarefa>-<descrição>` e `<tipo>: <descrição>`)
- [ ] Camadas respeitadas (ArchUnit passando)
- [ ] Chamadas externas com circuit breaker e fallback
- [ ] Eventos via Outbox e consumidores idempotentes
- [ ] Testes escritos e `./mvnw -pl <servico> verify` passando
- [ ] Nenhum segredo em arquivo versionado
- [ ] `docs/` e `README.md` atualizados, se necessário
