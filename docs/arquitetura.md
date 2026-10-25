# 🏛️ Arquitetura

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Microsserviços](#2-microsserviços)
3. [Camadas dentro de cada serviço](#3-camadas-dentro-de-cada-serviço)
4. [Comunicação entre serviços](#4-comunicação-entre-serviços)
5. [Circuit breaker e resiliência](#5-circuit-breaker-e-resiliência)
6. [Persistência (MongoDB + UUID)](#6-persistência-mongodb--uuid)
7. [Object storage (RustFS)](#7-object-storage-rustfs)
8. [Mensageria (RabbitMQ + Outbox)](#8-mensageria-rabbitmq--outbox)
9. [Integração com IA (Claude)](#9-integração-com-ia-claude)
10. [Observabilidade](#10-observabilidade)
11. [Decisões de arquitetura](#11-decisões-de-arquitetura)

---

## 1. Visão geral

```mermaid
flowchart LR
    U[Usuário / Front-end] --> GW[api-gateway]

    GW --> CS[conta-service]
    GW --> TS[transacao-service]
    GW --> OS[orcamento-service]
    GW --> DS[documento-service]
    GW --> IA[assistente-ia-service]

    TS -- HTTP + CB --> CS
    TS -- eventos --> MQ[(RabbitMQ)]
    MQ --> OS
    MQ --> IA
    MQ --> NS[notificacao-service]
    MQ --> CS

    CS --- M1[(Mongo accounts)]
    TS --- M2[(Mongo transactions)]
    OS --- M3[(Mongo budgets)]
    DS --- M4[(Mongo documents)]
    IA --- M5[(Mongo ai)]
    DS -- S3 + CB --> RF[(RustFS)]
    IA -- HTTPS + CB --> CL[API Claude]
```

Princípios que guiam o desenho:

- **Um assunto por serviço.** Cada serviço é dono de um pedaço do negócio.
- **Um banco por serviço.** Nenhum serviço lê o banco de outro.
- **Falhar sem derrubar tudo.** Toda chamada externa tem circuit breaker e plano B.
- **Assíncrono por padrão.** HTTP entre serviços só quando a resposta é indispensável na hora.

---

## 2. Microsserviços

| Serviço | Porta | Dono de | Publica | Consome |
|---|---|---|---|---|
| `api-gateway` | 8080 | Roteamento, autenticação, rate limit | — | — |
| `conta-service` | 8081 | Contas, carteiras, saldo | `BalanceUpdated` | `TransactionRegistered`, `TransactionReversed` |
| `transacao-service` | 8082 | Receitas e despesas | `TransactionRegistered`, `TransactionReversed` | `TransactionCategorized`, `ReceiptAttached` |
| `orcamento-service` | 8083 | Orçamentos e metas | `BudgetExceeded`, `GoalReached` | `TransactionRegistered`, `TransactionCategorized` |
| `documento-service` | 8084 | Comprovantes (metadados + arquivos) | `ReceiptAttached` | — |
| `assistente-ia-service` | 8085 | Categorização e insights | `TransactionCategorized` | `TransactionRegistered` |
| `notificacao-service` | 8086 | E-mail e push | — | `BudgetExceeded`, `GoalReached` |

---

## 3. Camadas dentro de cada serviço

Todo serviço segue a **Arquitetura Hexagonal (Ports & Adapters)** em três camadas:

```mermaid
flowchart TB
    subgraph INFRA[infra]
        WEB[web / controllers]
        MONGO[persistence / mongo]
        RABBIT[messaging / rabbit]
        CLIENT[client / http + CB]
        STORAGE[storage / rustfs + CB]
        AI[ai / claude + CB]
    end
    subgraph APP[application]
        UC[use cases]
        PIN[ports in]
        POUT[ports out]
    end
    subgraph DOM[domain]
        MODEL[entidades / value objects / eventos]
    end

    WEB --> PIN
    PIN --> UC
    UC --> MODEL
    UC --> POUT
    MONGO -. implementa .-> POUT
    RABBIT -. implementa .-> POUT
    CLIENT -. implementa .-> POUT
    STORAGE -. implementa .-> POUT
    AI -. implementa .-> POUT
```

| Camada | Responsabilidade | Pode depender de | Não pode conter |
|---|---|---|---|
| **domain** | Regras de negócio: entidades, value objects, eventos e exceções de negócio | Nada (Java puro) | Anotações do Spring, Mongo, Jackson, HTTP |
| **application** | Casos de uso: orquestra o domínio e chama as portas de saída | `domain` | Detalhes de banco, fila, HTTP ou circuit breaker |
| **infra** | Adaptadores: controllers, repositórios, publishers, clientes HTTP, storage, IA e configs | `application`, `domain` | Regra de negócio |

**Regra de ouro:** as dependências só apontam para dentro, `infra → application → domain`. Essa regra é verificada automaticamente com **ArchUnit** (ver [etapas.md](etapas.md#etapa-8--testes)).

### Exemplo de caso de uso

```java
// application/usecase/RegisterTransactionService.java
public class RegisterTransactionService implements RegisterTransactionUseCase {

    private final AccountClientPort accounts;
    private final TransactionRepositoryPort repository;
    private final EventPublisherPort events;

    @Override
    public TransactionResponse execute(RegisterTransactionCommand cmd) {
        accounts.findById(cmd.accountId());                 // valida a conta (CB na infra)

        var transaction = Transaction.create(cmd.accountId(), cmd.type(),
                Amount.of(cmd.amount(), cmd.currency()), cmd.description());

        repository.save(transaction);
        events.publish(transaction.registeredEvent());      // vai para a outbox

        return TransactionResponse.from(transaction);
    }
}
```

O caso de uso não sabe se a conta vem de HTTP, se existe circuit breaker ou se o evento vai para RabbitMQ.

---

## 4. Comunicação entre serviços

| Tipo | Quando usar | Tecnologia | Proteção |
|---|---|---|---|
| **Síncrona** | A resposta é necessária para continuar (ex.: a conta existe?) | HTTP (`RestClient` / HTTP Interfaces) | Circuit breaker + retry + timeout |
| **Assíncrona** | Reações a algo que já aconteceu (atualizar orçamento, notificar, categorizar) | RabbitMQ | Outbox + DLQ + idempotência |

Regras práticas:

- Evitar cadeias síncronas (A → B → C). Se surgir uma, provavelmente cabe um evento.
- Nenhum serviço chama outro para buscar dados que poderia manter em cópia local atualizada por eventos.

---

## 5. Circuit breaker e resiliência

### Estados

```mermaid
stateDiagram-v2
    [*] --> Fechado
    Fechado --> Aberto: taxa de falha ≥ limite
    Aberto --> MeioAberto: após tempo de espera
    MeioAberto --> Fechado: chamadas de teste OK
    MeioAberto --> Aberto: chamadas de teste falham
```

- **Fechado:** tudo normal, as chamadas passam.
- **Aberto:** chamadas bloqueadas na hora, vai direto para o fallback.
- **Meio-aberto:** deixa algumas chamadas passarem para testar se o serviço voltou.

### Onde fica

Sempre na camada **infra**, nos adaptadores que falam com algo externo.

| Circuito | Adaptador | Fallback |
|---|---|---|
| `conta-service` | `AccountClientAdapter` | Lança `ServiceUnavailableException` → HTTP 503 |
| `claude-api` | `ClaudeCategorizerAdapter` | `Category.UNCLASSIFIED` + reprocessamento posterior |
| `rustfs` | `RustFsReceiptAdapter` | Status do anexo `PENDING_UPLOAD` + nova tentativa agendada |

### Exemplo

```java
@Component
class AccountClientAdapter implements AccountClientPort {

    private final AccountHttpClient http;

    @CircuitBreaker(name = "conta-service", fallbackMethod = "accountUnavailable")
    @Retry(name = "conta-service")
    public AccountSummary findById(UUID accountId) {
        return http.findById(accountId);
    }

    private AccountSummary accountUnavailable(UUID accountId, Throwable cause) {
        throw new ServiceUnavailableException("conta-service", cause);
    }
}
```

> Exceções de negócio (ex.: `AccountNotFoundException`, HTTP 404) **não** contam como falha do circuito. Configure-as em `ignore-exceptions`.

### Configuração (YAML)

```yaml
resilience4j:
  circuitbreaker:
    configs:
      default:
        sliding-window-size: 20
        minimum-number-of-calls: 10
        failure-rate-threshold: 50
        wait-duration-in-open-state: 30s
        permitted-number-of-calls-in-half-open-state: 5
        record-exceptions:
          - java.io.IOException
          - java.util.concurrent.TimeoutException
          - org.springframework.web.client.HttpServerErrorException
        ignore-exceptions:
          - br.com.finance.commons.exception.BusinessException
    instances:
      conta-service:
        base-config: default
      rustfs:
        base-config: default
      claude-api:
        base-config: default
        failure-rate-threshold: 40
        slow-call-duration-threshold: 8s
        slow-call-rate-threshold: 50
  retry:
    instances:
      conta-service:
        max-attempts: 3
        wait-duration: 200ms
        enable-exponential-backoff: true
  timelimiter:
    instances:
      claude-api:
        timeout-duration: 10s
```

### Ordem de aplicação

`Retry ( CircuitBreaker ( TimeLimiter ( chamada ) ) )`: o retry tenta de novo, o circuit breaker conta as falhas e o time limiter corta a espera.

---

## 6. Persistência (MongoDB + UUID)

- **Um database por serviço:** `accounts`, `transactions`, `budgets`, `documents`, `ai`.
- **IDs são UUID gerados na aplicação** (no domínio), não pelo banco. Assim a entidade já nasce com identidade e o evento pode ser publicado com o ID certo.
- UUID gravado no formato **standard** (binário subtipo 4):

```yaml
spring:
  mongodb:
    uri: mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@localhost:27017/transactions?authSource=admin
    representation:
      uuid: standard
```

- A entidade de domínio (`Transaction`) é diferente do documento do Mongo (`TransactionDocument`). Um mapper converte entre os dois, e o domínio não recebe anotações `@Document`.
- Valores monetários usam `Decimal128` no Mongo e `BigDecimal` no Java. **Nunca `double`.**
- Índices criados por migração (Mongock), não por `auto-index-creation`.

---

## 7. Object storage (RustFS)

- Acesso pela **API S3** com o AWS SDK v2, usando endpoint customizado e `pathStyleAccess = true`.
- Bucket `receipts`, com chave no formato `{userId}/{year}/{month}/{uuid}.{ext}`.
- **Upload e download por URL pré-assinada**: o arquivo vai direto do cliente para o RustFS, sem passar pelo serviço. O serviço só gera o link e guarda os metadados.
- Metadados (nome, tamanho, tipo, hash, transação vinculada) ficam no Mongo do `documento-service`.

---

## 8. Mensageria (RabbitMQ + Outbox)

### Topologia

```mermaid
flowchart LR
    TS[transacao-service] --> EX{{finance.events<br/>topic exchange}}
    EX -- transaction.registered --> Q1[orcamento.transaction-registered]
    EX -- transaction.registered --> Q2[ia.transaction-registered]
    EX -- transaction.registered --> Q3[conta.transaction-registered]
    EX -- budget.exceeded --> Q4[notificacao.budget-exceeded]
    Q1 -. falha repetida .-> DLX{{finance.dlx}}
    DLX --> DLQ[*.dlq]
```

- **Exchange `topic`** com routing key `<agregado>.<evento>`.
- **Uma fila por consumidor**, no formato `<servico>.<evento>`.
- **DLQ por fila**, para mensagens que falharam após o número máximo de tentativas.
- Mensagens em JSON, com envelope padrão:

```json
{
  "eventId": "8f0d1e7a-...-uuid",
  "type": "TransactionRegistered",
  "version": 1,
  "occurredAt": "2026-10-20T21:37:00Z",
  "traceparent": "00-...",
  "payload": { "transactionId": "...", "accountId": "...", "amount": 59.90 }
}
```

### Outbox

```mermaid
sequenceDiagram
    participant UC as Caso de uso
    participant DB as MongoDB
    participant OB as OutboxRelay (agendado)
    participant MQ as RabbitMQ

    UC->>DB: salva transação + documento na coleção outbox (mesma transação)
    loop a cada 1s
        OB->>DB: busca eventos PENDING
        OB->>MQ: publica (com publisher confirm)
        OB->>DB: marca como SENT
    end
```

> A transação multi-documento do MongoDB exige **replica set**. O `docker-compose` já sobe o Mongo como replica set de um nó.

### Idempotência no consumidor

Cada consumidor grava o `eventId` processado na coleção `processed_events` (com índice único). Se o mesmo evento chegar de novo, ele é ignorado.

---

## 9. Integração com IA (Claude)

- Fica isolada no `assistente-ia-service`. Nenhum outro serviço chama a Anthropic diretamente.
- Implementada com **Spring AI** (`spring-ai-starter-model-anthropic`).
- Usos:
  - **Categorização:** recebe `TransactionRegistered`, pede ao Claude uma categoria dentro de uma lista fechada e publica `TransactionCategorized`.
  - **Insights:** endpoint sob demanda que resume os gastos do mês.
- A resposta é pedida em **saída estruturada (JSON)** e validada. Categoria fora da lista vira `UNCLASSIFIED`.
- Protegida por circuit breaker + time limiter. Com o circuito aberto, a transação continua válida e é recategorizada depois.
- Dados sensíveis (nome do titular, número da conta) **não** são enviados no prompt.

```yaml
spring:
  ai:
    anthropic:
      api-key: ${ANTHROPIC_API_KEY}
      chat:
        options:
          model: ${ANTHROPIC_MODEL:claude-sonnet-5-5}
          temperature: 0.0
          max-tokens: 300
```

---

## 10. Observabilidade

```mermaid
flowchart LR
    S[Microsserviços] -- OTLP traces --> C[OTel Collector]
    C --> J[Jaeger]
    S -- /actuator/prometheus --> P[Prometheus]
    P --> G[Grafana]
    J --> G
```

| Sinal | Ferramenta | Exemplo de uso |
|---|---|---|
| **Traces** | OpenTelemetry → Jaeger | Ver uma requisição passando pelo gateway, transacao-service, RabbitMQ e orcamento-service |
| **Métricas** | Micrometer → Prometheus → Grafana | Latência, taxa de erro, estado dos circuit breakers, tamanho das filas |
| **Logs** | Logs estruturados em JSON com `traceId` | Ir de um log para o trace correspondente |

- O contexto do trace (`traceparent`) é propagado também nos **headers das mensagens do RabbitMQ**.
- Dashboards versionados em `deploy/grafana/dashboards/`.
- Alertas sugeridos: circuito aberto por mais de 2 min, DLQ com mensagens, p95 de latência acima de 1s.

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, prometheus, circuitbreakers
  health:
    circuitbreakers:
      enabled: true
  tracing:
    sampling:
      probability: 1.0      # 100% em local; reduzir em produção
  otlp:
    tracing:
      endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT}/v1/traces
```

---

## 11. Decisões de arquitetura

| # | Decisão | Motivo | Alternativa descartada |
|---|---|---|---|
| 1 | Microsserviços por assunto de negócio | Evolução e deploy independentes; falha isolada | Monólito modular (mais simples, mas menos isolamento) |
| 2 | Hexagonal com três camadas | Regra de negócio testável e independente de tecnologia | Camadas tradicionais controller/service/repository |
| 3 | Circuit breaker só na infra | Resiliência é detalhe técnico, não regra de negócio | Anotações no caso de uso |
| 4 | UUID gerado na aplicação | ID conhecido antes de salvar; eventos consistentes | ObjectId do Mongo |
| 5 | Outbox para eventos | Garante que evento e dado são gravados juntos | Publicar direto após salvar (pode perder evento) |
| 6 | IA isolada em um serviço | Custo, limites e falhas da API concentrados num lugar | Chamar o Claude de cada serviço |
| 7 | URL pré-assinada no RustFS | Arquivos grandes não passam pelos serviços | Upload via multipart no serviço |
