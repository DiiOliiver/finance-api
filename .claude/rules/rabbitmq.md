---
paths:
  - "**/infra/messaging/**"
  - "shared/financas-eventos/**"
  - "deploy/rabbitmq/**"
---
# RabbitMQ

Complementa o `CLAUDE.md` (Outbox, idempotência, envelope, versões e nomes já estão lá).

## Topologia
- Exchanges, filas, bindings e DLQs são declarados no código (`RabbitTopologyConfig`) **e** em `deploy/rabbitmq/definitions.json`. Mantenha os dois iguais.
- Filas do tipo `quorum` e duráveis. Mensagens persistentes.
- Cada fila tem seu `x-dead-letter-exchange` apontando para `financas.dlx`.

## Publicação
- Só o `OutboxRelay` publica. Use publisher confirms e marque a outbox como enviada apenas após o confirm.
- Conversor de mensagens: Jackson (`JacksonJsonMessageConverter`), com o tipo indicado pelo campo `type` do envelope, não pelo nome da classe Java.

## Consumo
- O listener só desserializa, verifica idempotência e chama um caso de uso. Nenhuma regra de negócio nele.
- Ack só após o processamento terminar com sucesso.
- Retry do consumidor com backoff exponencial (`spring.rabbitmq.listener.simple.retry`), máximo 5 tentativas. Depois disso a mensagem é rejeitada sem requeue e cai na DLQ.
- Erros que nunca vão se resolver com retry (JSON inválido, versão desconhecida) vão direto para a DLQ (`AmqpRejectAndDontRequeueException`).
- `prefetch` baixo (10) e `concurrency` configurável por fila.
- Não assuma ordem de entrega entre mensagens.

## Contratos (`shared/financas-eventos`)
- Contratos são `record` sem lógica, sem dependência de Spring.
- Só adicione campos opcionais numa versão existente. Remover ou mudar tipo exige `V2`.
- Consumidores ignoram campos desconhecidos (`FAIL_ON_UNKNOWN_PROPERTIES: false`).
