# 📁 Estrutura de Pastas

## Sumário

1. [Raiz do repositório](#1-raiz-do-repositório)
2. [Bibliotecas compartilhadas (`shared/`)](#2-bibliotecas-compartilhadas-shared)
3. [Estrutura de um microsserviço](#3-estrutura-de-um-microsserviço)
4. [Estrutura de testes](#4-estrutura-de-testes)
5. [Infraestrutura local (`deploy/`)](#5-infraestrutura-local-deploy)
6. [Convenções de nomes](#6-convenções-de-nomes)
7. [Onde colocar cada coisa](#7-onde-colocar-cada-coisa)

---

## 1. Raiz do repositório

Monorepo: um único repositório Git com todos os microsserviços na raiz.

```
finance-api/
├── .git/                       ← único repositório Git (não deixe .git dentro dos serviços)
├── .gitignore                  ← único .gitignore
├── .editorconfig
├── .mvn/wrapper/               ← Maven Wrapper (único, na raiz)
├── mvnw / mvnw.cmd
├── pom.xml                     ← POM pai e agregador: Java 25, Spring Boot 4.1.1, módulos, versões, plugins
├── README.md                   ← como configurar, subir e testar
├── CLAUDE.md                   ← regras para o Claude trabalhar no repositório
│
├── docs/                       ← esta documentação
│   ├── README.md
│   ├── arquitetura.md
│   ├── estrutura-de-pastas.md
│   ├── fluxos.md
│   ├── etapas.md
│   └── conceitos.md
│
├── deploy/                     ← tudo para subir o ambiente (Docker Compose, .env.example, configs)
│
├── shared/                     ← código compartilhado (só contratos e utilitários técnicos)
│   ├── financas-eventos/
│   └── financas-commons/
│
├── api-gateway/                ← um módulo Maven por microsserviço, direto na raiz
├── conta-service/
├── transacao-service/
├── orcamento-service/
├── documento-service/
├── assistente-ia-service/
└── notificacao-service/
```

### POM pai (agregador)

O `pom.xml` da raiz lista todos os módulos. Assim, `./mvnw verify` na raiz compila e testa tudo.

```xml
<groupId>br.com.finance</groupId>
<artifactId>finance-api</artifactId>
<version>0.0.1-SNAPSHOT</version>
<packaging>pom</packaging>

<modules>
    <module>shared/financas-eventos</module>
    <module>shared/financas-commons</module>
    <module>api-gateway</module>
    <module>conta-service</module>
    <module>transacao-service</module>
    <module>orcamento-service</module>
    <module>documento-service</module>
    <module>assistente-ia-service</module>
    <module>notificacao-service</module>
</modules>
```

Cada serviço aponta para ele como `<parent>`:

```xml
<parent>
    <groupId>br.com.finance</groupId>
    <artifactId>finance-api</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <relativePath>../pom.xml</relativePath>
</parent>
```

Os módulos dentro de `shared/` usam `<relativePath>../../pom.xml</relativePath>`.

### Nomes dos módulos

| Pasta | Artifact | Pacote base |
|---|---|---|
| `api-gateway` | `api-gateway` | `br.com.finance.gateway` |
| `conta-service` | `conta-service` | `br.com.finance.conta` |
| `transacao-service` | `transacao-service` | `br.com.finance.transacao` |
| `orcamento-service` | `orcamento-service` | `br.com.finance.orcamento` |
| `documento-service` | `documento-service` | `br.com.finance.documento` |
| `assistente-ia-service` | `assistente-ia-service` | `br.com.finance.assistenteia` |
| `notificacao-service` | `notificacao-service` | `br.com.finance.notificacao` |
| `shared/financas-eventos` | `financas-eventos` | `br.com.finance.eventos` |
| `shared/financas-commons` | `financas-commons` | `br.com.finance.commons` |

> Pacote Java não aceita hífen: `assistente-ia` vira `assistenteia`.

---

## 2. Bibliotecas compartilhadas (`shared/`)

```
shared/
├── financas-eventos/
│   ├── pom.xml
│   └── src/main/java/br/com/finance/eventos/
│       ├── EventEnvelope.java               ← eventId, type, version, occurredAt, payload
│       ├── transacao/
│       │   ├── TransactionRegisteredV1.java
│       │   ├── TransactionReversedV1.java
│       │   └── TransactionCategorizedV1.java
│       ├── orcamento/
│       │   └── BudgetExceededV1.java
│       └── documento/
│           └── ReceiptAttachedV1.java
│
└── financas-commons/
    ├── pom.xml
    └── src/main/java/br/com/finance/commons/
        ├── exception/
        │   ├── BusinessException.java       ← base das exceções de negócio (ignorada pelo CB)
        │   └── ServiceUnavailableException.java
        ├── web/
        │   └── ProblemDetailsHandler.java   ← respostas de erro padronizadas (RFC 9457)
        └── observability/
            └── RabbitTracingConfig.java     ← propaga o trace nas mensagens
```

> ⚠️ **Regra:** `shared/` nunca contém regra de negócio nem entidades de domínio. Se a regra está em uma lib, os serviços ficam acoplados e precisam ser publicados juntos.

---

## 3. Estrutura de um microsserviço

Exemplo com o `transacao-service`. Todos os serviços seguem o mesmo molde.

```
transacao-service/
├── pom.xml
├── Dockerfile
└── src/
    ├── main/
    │   ├── java/br/com/finance/transacao/
    │   │   ├── TransacaoServiceApplication.java
    │   │   │
    │   │   ├── domain/                              ══ DOMÍNIO (Java puro) ══
    │   │   │   ├── model/
    │   │   │   │   ├── Transaction.java             entidade / agregado raiz
    │   │   │   │   ├── TransactionId.java           record com UUID
    │   │   │   │   ├── Amount.java                  value object: BigDecimal + moeda
    │   │   │   │   ├── TransactionType.java         enum INCOME / EXPENSE
    │   │   │   │   ├── TransactionStatus.java       enum ACTIVE / REVERSED
    │   │   │   │   └── Category.java
    │   │   │   ├── event/
    │   │   │   │   ├── DomainEvent.java             interface marcadora
    │   │   │   │   ├── TransactionRegistered.java
    │   │   │   │   └── TransactionReversed.java
    │   │   │   └── exception/
    │   │   │       ├── InvalidTransactionException.java
    │   │   │       └── TransactionAlreadyReversedException.java
    │   │   │
    │   │   ├── application/                         ══ APLICAÇÃO (casos de uso) ══
    │   │   │   ├── port/
    │   │   │   │   ├── in/                          o que o serviço oferece
    │   │   │   │   │   ├── RegisterTransactionUseCase.java
    │   │   │   │   │   ├── ReverseTransactionUseCase.java
    │   │   │   │   │   ├── ListTransactionsUseCase.java
    │   │   │   │   │   └── ApplyCategoryUseCase.java
    │   │   │   │   └── out/                         o que o serviço precisa
    │   │   │   │       ├── TransactionRepositoryPort.java
    │   │   │   │       ├── AccountClientPort.java
    │   │   │   │       └── EventPublisherPort.java
    │   │   │   ├── usecase/
    │   │   │   │   ├── RegisterTransactionService.java
    │   │   │   │   ├── ReverseTransactionService.java
    │   │   │   │   ├── ListTransactionsService.java
    │   │   │   │   └── ApplyCategoryService.java
    │   │   │   └── dto/
    │   │   │       ├── RegisterTransactionCommand.java
    │   │   │       ├── TransactionFilter.java
    │   │   │       ├── AccountSummary.java
    │   │   │       └── TransactionResponse.java
    │   │   │
    │   │   └── infra/                               ══ INFRAESTRUTURA (adaptadores) ══
    │   │       ├── web/
    │   │       │   ├── TransactionController.java
    │   │       │   ├── request/RegisterTransactionRequest.java
    │   │       │   ├── response/TransactionHttpResponse.java
    │   │       │   └── mapper/TransactionWebMapper.java
    │   │       ├── persistence/mongo/
    │   │       │   ├── TransactionDocument.java     @Document (só aqui!)
    │   │       │   ├── TransactionMongoRepository.java Spring Data
    │   │       │   ├── TransactionRepositoryAdapter.java implementa TransactionRepositoryPort
    │   │       │   ├── mapper/TransactionDocumentMapper.java
    │   │       │   └── migration/                   changesets do Mongock (índices)
    │   │       ├── messaging/rabbit/
    │   │       │   ├── RabbitTopologyConfig.java    exchange, filas, bindings, DLQ
    │   │       │   ├── outbox/
    │   │       │   │   ├── OutboxDocument.java
    │   │       │   │   ├── OutboxEventPublisher.java   implementa EventPublisherPort
    │   │       │   │   └── OutboxRelay.java            @Scheduled → RabbitMQ
    │   │       │   └── listener/
    │   │       │       └── TransactionCategorizedListener.java
    │   │       ├── client/account/
    │   │       │   ├── AccountHttpClient.java      HTTP Interface (@GetExchange)
    │   │       │   └── AccountClientAdapter.java   ← @CircuitBreaker + @Retry
    │   │       └── config/
    │   │           ├── UseCaseConfig.java           cria os beans dos casos de uso
    │   │           ├── HttpClientConfig.java
    │   │           └── MongoConfig.java
    │   │
    │   └── resources/
    │       ├── application.yml                      configuração comum
    │       ├── application-local.yml
    │       ├── application-test.yml
    │       ├── application-prod.yml
    │       └── logback-spring.xml                   logs em JSON com traceId
    │
    └── test/                                        (ver seção 4)
```

### Por que os casos de uso são criados em `UseCaseConfig`?

Para manter a camada `application` **sem anotações do Spring**. Os serviços de caso de uso são classes Java comuns, e quem os registra no Spring é a infra:

```java
@Configuration
class UseCaseConfig {
    @Bean
    RegisterTransactionUseCase registerTransaction(AccountClientPort accounts,
                                                   TransactionRepositoryPort repository,
                                                   EventPublisherPort events) {
        return new RegisterTransactionService(accounts, repository, events);
    }
}
```

### Particularidades por serviço

| Serviço | Pastas extras em `infra/` |
|---|---|
| `documento-service` | `storage/rustfs/` → `RustFsConfig`, `RustFsReceiptAdapter` (CB), `PresignedUrlGenerator` |
| `assistente-ia-service` | `ai/claude/` → `ClaudeCategorizerAdapter` (CB + TimeLimiter), `PromptTemplates`, `resources/prompts/*.st` |
| `notificacao-service` | `notifier/email/`, `notifier/push/` |
| `api-gateway` | Sem `domain/`/`application/`. Só `config/` (rotas, segurança, rate limit) |

---

## 4. Estrutura de testes

```
src/test/java/br/com/finance/transacao/
├── domain/                                  JUnit puro, sem Spring
│   ├── model/TransactionTest.java
│   └── model/AmountTest.java
├── application/                             JUnit + Mockito
│   └── usecase/RegisterTransactionServiceTest.java
├── infra/                                   Testcontainers (*IT)
│   ├── persistence/mongo/TransactionRepositoryAdapterIT.java
│   ├── messaging/rabbit/OutboxRelayIT.java
│   ├── client/account/AccountClientAdapterIT.java  ← simula falhas e verifica o CB
│   └── web/TransactionControllerIT.java
├── architecture/
│   └── LayerRulesTest.java                  ArchUnit: domain não depende de infra etc.
└── support/
    ├── ContainersConfig.java                @TestConfiguration com @ServiceConnection
    └── fixtures/TransactionFixtures.java

src/test/resources/
├── application-test.yml
└── wiremock/                                respostas simuladas do conta-service
```

---

## 5. Infraestrutura local (`deploy/`)

```
deploy/
├── .env.example                 modelo das variáveis (copiar para .env)
├── docker-compose.yml           infraestrutura: mongo, rabbitmq, rustfs, otel, jaeger, prometheus, grafana
├── docker-compose.services.yml  os microsserviços (opcional)
├── mongo/
│   └── init-replica-set.js      healthcheck que inicia o replica set (necessário para transações)
├── rabbitmq/
│   └── definitions.json         exchanges, filas e DLQs; importado pelo serviço rabbitmq-definitions
├── rustfs/
│   └── create-buckets.sh        cria o bucket "receipts"
├── otel-collector.yml           recebe OTLP e envia para o Jaeger
├── prometheus.yml               de onde coletar métricas (cada serviço /actuator/prometheus)
└── grafana/
    ├── provisioning/
    │   ├── datasources/datasources.yml
    │   └── dashboards/dashboards.yml
    └── dashboards/
        ├── overview.json
        ├── circuit-breakers.json
        └── rabbitmq.json
```

---

## 6. Convenções de nomes

| Item | Padrão | Exemplo |
|---|---|---|
| Pacote base | `br.com.finance.<servico>` | `br.com.finance.transacao` |
| Porta de entrada | `<Acao><Entidade>UseCase` | `RegisterTransactionUseCase` |
| Implementação do caso de uso | `<Acao><Entidade>Service` | `RegisterTransactionService` |
| Porta de saída | `<Coisa>Port` | `TransactionRepositoryPort` |
| Adaptador | `<Tecnologia/Coisa>Adapter` | `AccountClientAdapter` |
| Documento Mongo | `<Entidade>Document` | `TransactionDocument` |
| Evento de domínio | Verbo no passado | `TransactionRegistered` |
| Contrato de evento (lib) | `<Evento>V<n>` | `TransactionRegisteredV1` |
| Fila RabbitMQ | `<servico-consumidor>.<evento>` | `orcamento.transaction-registered` |
| Routing key | `<agregado>.<evento>` | `transaction.registered` |
| Circuit breaker | nome do destino | `conta-service`, `claude-api`, `rustfs` |
| Teste unitário | `<Classe>Test` | `AmountTest` |
| Teste de integração | `<Classe>IT` | `AccountClientAdapterIT` |

---

## 7. Onde colocar cada coisa

| Quero criar... | Vai em |
|---|---|
| Uma regra como "despesa não pode ser zero" | `domain/model/` (dentro da entidade ou value object) |
| Um novo fluxo, como "transferir entre contas" | `application/port/in/` + `application/usecase/` |
| Uma necessidade externa, como "buscar cotação do dólar" | Interface em `application/port/out/`, implementação em `infra/client/` |
| Um endpoint REST | `infra/web/` |
| Uma nova coleção no Mongo | `infra/persistence/mongo/` + changeset em `migration/` |
| Um novo evento publicado | Evento em `domain/event/` + contrato em `shared/financas-eventos/` |
| Um consumidor de evento | `infra/messaging/rabbit/listener/` (que chama um caso de uso) |
| Uma configuração de circuit breaker | `application.yml` + anotação no adaptador em `infra/` |
| Um dashboard do Grafana | `deploy/grafana/dashboards/` |
