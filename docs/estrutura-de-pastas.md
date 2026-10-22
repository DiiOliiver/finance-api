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
│       ├── EnvelopeEvento.java              ← eventId, type, version, occurredAt, payload
│       ├── transacao/
│       │   ├── TransacaoRegistradaV1.java
│       │   ├── TransacaoEstornadaV1.java
│       │   └── TransacaoCategorizadaV1.java
│       ├── orcamento/
│       │   └── OrcamentoExcedidoV1.java
│       └── documento/
│           └── ComprovanteAnexadoV1.java
│
└── financas-commons/
    ├── pom.xml
    └── src/main/java/br/com/finance/commons/
        ├── exception/
        │   ├── NegocioException.java        ← base das exceções de negócio (ignorada pelo CB)
        │   └── ServicoIndisponivelException.java
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
    │   │   ├── TransacaoApplication.java
    │   │   │
    │   │   ├── domain/                              ══ DOMÍNIO (Java puro) ══
    │   │   │   ├── model/
    │   │   │   │   ├── Transacao.java               entidade / agregado raiz
    │   │   │   │   ├── TransacaoId.java             record com UUID
    │   │   │   │   ├── Valor.java                   value object: BigDecimal + moeda
    │   │   │   │   ├── TipoTransacao.java           enum RECEITA / DESPESA
    │   │   │   │   ├── StatusTransacao.java         enum ATIVA / ESTORNADA
    │   │   │   │   └── Categoria.java
    │   │   │   ├── event/
    │   │   │   │   ├── EventoDominio.java           interface marcadora
    │   │   │   │   ├── TransacaoRegistrada.java
    │   │   │   │   └── TransacaoEstornada.java
    │   │   │   └── exception/
    │   │   │       ├── TransacaoInvalidaException.java
    │   │   │       └── TransacaoJaEstornadaException.java
    │   │   │
    │   │   ├── application/                         ══ APLICAÇÃO (casos de uso) ══
    │   │   │   ├── port/
    │   │   │   │   ├── in/                          o que o serviço oferece
    │   │   │   │   │   ├── RegistrarTransacaoUseCase.java
    │   │   │   │   │   ├── EstornarTransacaoUseCase.java
    │   │   │   │   │   ├── ListarTransacoesUseCase.java
    │   │   │   │   │   └── AplicarCategoriaUseCase.java
    │   │   │   │   └── out/                         o que o serviço precisa
    │   │   │   │       ├── TransacaoRepositoryPort.java
    │   │   │   │       ├── ContaClientPort.java
    │   │   │   │       └── EventPublisherPort.java
    │   │   │   ├── usecase/
    │   │   │   │   ├── RegistrarTransacaoService.java
    │   │   │   │   ├── EstornarTransacaoService.java
    │   │   │   │   ├── ListarTransacoesService.java
    │   │   │   │   └── AplicarCategoriaService.java
    │   │   │   └── dto/
    │   │   │       ├── RegistrarTransacaoCommand.java
    │   │   │       ├── FiltroTransacoes.java
    │   │   │       ├── ContaResumo.java
    │   │   │       └── TransacaoResponse.java
    │   │   │
    │   │   └── infra/                               ══ INFRAESTRUTURA (adaptadores) ══
    │   │       ├── web/
    │   │       │   ├── TransacaoController.java
    │   │       │   ├── request/RegistrarTransacaoRequest.java
    │   │       │   ├── response/TransacaoHttpResponse.java
    │   │       │   └── mapper/TransacaoWebMapper.java
    │   │       ├── persistence/mongo/
    │   │       │   ├── TransacaoDocument.java       @Document (só aqui!)
    │   │       │   ├── TransacaoMongoRepository.java  Spring Data
    │   │       │   ├── TransacaoRepositoryAdapter.java implementa TransacaoRepositoryPort
    │   │       │   ├── mapper/TransacaoDocumentMapper.java
    │   │       │   └── migration/                   changesets do Mongock (índices)
    │   │       ├── messaging/rabbit/
    │   │       │   ├── RabbitTopologyConfig.java    exchange, filas, bindings, DLQ
    │   │       │   ├── outbox/
    │   │       │   │   ├── OutboxDocument.java
    │   │       │   │   ├── OutboxEventPublisher.java   implementa EventPublisherPort
    │   │       │   │   └── OutboxRelay.java            @Scheduled → RabbitMQ
    │   │       │   └── listener/
    │   │       │       └── TransacaoCategorizadaListener.java
    │   │       ├── client/conta/
    │   │       │   ├── ContaHttpClient.java         HTTP Interface (@GetExchange)
    │   │       │   └── ContaClientAdapter.java      ← @CircuitBreaker + @Retry
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
    RegistrarTransacaoUseCase registrarTransacao(ContaClientPort contas,
                                                 TransacaoRepositoryPort repo,
                                                 EventPublisherPort eventos) {
        return new RegistrarTransacaoService(contas, repo, eventos);
    }
}
```

### Particularidades por serviço

| Serviço | Pastas extras em `infra/` |
|---|---|
| `documento-service` | `storage/rustfs/` → `RustFsConfig`, `RustFsComprovanteAdapter` (CB), `PresignedUrlGenerator` |
| `assistente-ia-service` | `ai/claude/` → `ClaudeCategorizadorAdapter` (CB + TimeLimiter), `PromptTemplates`, `resources/prompts/*.st` |
| `notificacao-service` | `notifier/email/`, `notifier/push/` |
| `api-gateway` | Sem `domain/`/`application/`. Só `config/` (rotas, segurança, rate limit) |

---

## 4. Estrutura de testes

```
src/test/java/br/com/finance/transacao/
├── domain/                                  JUnit puro, sem Spring
│   ├── model/TransacaoTest.java
│   └── model/ValorTest.java
├── application/                             JUnit + Mockito
│   └── usecase/RegistrarTransacaoServiceTest.java
├── infra/                                   Testcontainers (*IT)
│   ├── persistence/mongo/TransacaoRepositoryAdapterIT.java
│   ├── messaging/rabbit/OutboxRelayIT.java
│   ├── client/conta/ContaClientAdapterIT.java     ← simula falhas e verifica o CB
│   └── web/TransacaoControllerIT.java
├── arquitetura/
│   └── RegrasDeCamadasTest.java             ArchUnit: domain não depende de infra etc.
└── support/
    ├── ContainersConfig.java                @TestConfiguration com @ServiceConnection
    └── fixtures/TransacaoFixtures.java

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
│   └── init-replica-set.js      inicializa o replica set (necessário para transações)
├── rabbitmq/
│   ├── rabbitmq.conf
│   └── definitions.json         exchanges, filas e DLQs pré-criadas
├── rustfs/
│   └── create-buckets.sh        cria o bucket "comprovantes"
├── otel-collector.yml           recebe OTLP e envia para o Jaeger
├── prometheus.yml               de onde coletar métricas (cada serviço /actuator/prometheus)
└── grafana/
    ├── provisioning/
    │   ├── datasources/datasources.yml
    │   └── dashboards/dashboards.yml
    └── dashboards/
        ├── visao-geral.json
        ├── circuit-breakers.json
        └── rabbitmq.json
```

---

## 6. Convenções de nomes

| Item | Padrão | Exemplo |
|---|---|---|
| Pacote base | `br.com.finance.<servico>` | `br.com.finance.transacao` |
| Porta de entrada | `<Acao><Entidade>UseCase` | `RegistrarTransacaoUseCase` |
| Implementação do caso de uso | `<Acao><Entidade>Service` | `RegistrarTransacaoService` |
| Porta de saída | `<Coisa>Port` | `TransacaoRepositoryPort` |
| Adaptador | `<Tecnologia/Coisa>Adapter` | `ContaClientAdapter` |
| Documento Mongo | `<Entidade>Document` | `TransacaoDocument` |
| Evento de domínio | Verbo no passado | `TransacaoRegistrada` |
| Contrato de evento (lib) | `<Evento>V<n>` | `TransacaoRegistradaV1` |
| Fila RabbitMQ | `<servico-consumidor>.<evento>` | `orcamento.transacao-registrada` |
| Routing key | `<agregado>.<evento>` | `transacao.registrada` |
| Circuit breaker | nome do destino | `conta-service`, `claude-api`, `rustfs` |
| Teste unitário | `<Classe>Test` | `ValorTest` |
| Teste de integração | `<Classe>IT` | `ContaClientAdapterIT` |

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
