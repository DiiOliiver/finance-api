# 🧭 Etapas de Construção

Roteiro sugerido para construir o projeto. Cada etapa entrega algo que funciona e pode ser testado antes de seguir para a próxima.

Cada tarefa de uma etapa segue o fluxo **develop → branch → pull request → develop**: uma branch criada a partir da `develop`, com o código da tarefa no nome (`feature/e2-t1-account-domain`), que volta por pull request. Commits direto em `main`, `develop` e `homol` não são permitidos, e branches e commits seguem o Conventional Commits. Detalhes em [Fluxo de trabalho](../README.md#fluxo-de-trabalho) e [Padrão de nomes](../README.md#padrão-de-nomes).

## Sumário

| Etapa | Entrega |
|---|---|
| [0 — Fundação](#etapa-0--fundação) | Repositório, POM pai, convenções |
| [1 — Ambiente local](#etapa-1--ambiente-local) | Docker Compose com toda a infraestrutura |
| [2 — Primeiro serviço](#etapa-2--primeiro-serviço-conta-service) | `conta-service` com as três camadas |
| [3 — Comunicação síncrona + circuit breaker](#etapa-3--comunicação-síncrona--circuit-breaker) | `transacao-service` chamando `conta-service` |
| [4 — Mensageria](#etapa-4--mensageria) | Eventos, outbox, DLQ, idempotência |
| [5 — Serviços consumidores](#etapa-5--serviços-consumidores) | Orçamento e notificação |
| [6 — Storage e IA](#etapa-6--storage-e-ia) | RustFS e Claude, ambos com CB |
| [7 — Importação de extratos OFX](#etapa-7--importação-de-extratos-ofx) | Upload de OFX, leitura dos lançamentos e categorização por IA |
| [8 — Testes](#etapa-8--testes) | Estratégia completa de testes |
| [9 — Observabilidade](#etapa-9--observabilidade) | Traces, métricas, dashboards, alertas |
| [10 — Gateway e segurança](#etapa-10--gateway-e-segurança) | Entrada única e autenticação |
| [11 — Rumo à produção](#etapa-11--rumo-à-produção) | CI/CD, imagens, configuração de produção |

---

## Etapa 0 — Fundação

- [ ] Criar o repositório `finance-api` com `README.md`, `CLAUDE.md`, `.gitignore`, `.editorconfig` e as pastas `docs/` e `deploy/`.
- [x] Criar o `pom.xml` pai e agregador (`packaging` = `pom`):
  - `parent`: `spring-boot-starter-parent` 4.1.1
  - `java.version` = 25
  - `<modules>` com `shared/*` e todos os serviços
  - `dependencyManagement` com Spring Cloud, Spring AI, AWS SDK v2, Mongock, ArchUnit e WireMock (Testcontainers já vem gerenciado pelo Spring Boot)
  - Plugins: Surefire (`*Test`), Failsafe (`*IT`), JaCoCo (meta de 80% em `domain` e `application`, checada no `verify`)
- [x] Gerar cada serviço no Spring Initializr (Maven, Java 25, Boot 4.1.1, YAML, Group `br.com.finance`) e colocar a pasta na raiz.
- [x] Em cada serviço gerado:
  - trocar o `<parent>` para `finance-api` com `<relativePath>../pom.xml</relativePath>`
  - apagar `.git`, `.gitignore`, `.gitattributes`, `HELP.md`, `mvnw`, `mvnw.cmd`, `.mvn/` (os de Git e do wrapper ficam só na raiz)
  - remover do POM do serviço versões já gerenciadas pelo pai (`java.version`, BOMs do Spring Cloud e do Spring AI) e as tags vazias do Initializr (`name`, `licenses`, `developers`, `scm`); o POM raiz é que bloqueia a herança desses metadados do Spring Boot
- [x] Mover um Maven Wrapper para a raiz.
- [ ] Criar `shared/financas-eventos` e `shared/financas-commons` vazios.

**Pronto quando:** `./mvnw verify` roda com sucesso na raiz.

---

## Etapa 1 — Ambiente local

- [ ] `deploy/docker-compose.yml` com:
  - MongoDB como **replica set** de um nó (necessário para transações)
  - RabbitMQ com painel de gerenciamento e `definitions.json`
  - RustFS + script que cria o bucket `comprovantes`
  - OpenTelemetry Collector, Jaeger, Prometheus, Grafana
- [ ] `healthcheck` em todos os containers.
- [ ] `.env.example` documentado.

**Pronto quando:** `docker compose ps` mostra tudo `healthy` e os painéis abrem (RabbitMQ, RustFS, Jaeger, Grafana).

---

## Etapa 2 — Primeiro serviço (`conta-service`)

Serve de **molde** para todos os outros.

- [ ] **domain:** `Conta`, `ContaId` (UUID), `Valor`, `Moeda`, exceções de negócio.
- [ ] **application:** `CriarContaUseCase`, `BuscarContaUseCase`, `ContaRepositoryPort`.
- [ ] **infra:**
  - `ContaController` com respostas de erro em Problem Details
  - `ContaDocument`, `ContaRepositoryAdapter`, mapper
  - `representation.uuid: standard` no YAML
  - Índices via Mongock
- [ ] Actuator com `health` e `prometheus`.
- [ ] Testes: domínio (JUnit), caso de uso (Mockito), repositório (Testcontainers) e regras de camada (ArchUnit).

**Pronto quando:** dá para criar e buscar uma conta via `curl`, e os UUIDs aparecem legíveis no Mongo.

---

## Etapa 3 — Comunicação síncrona + circuit breaker

- [ ] Criar o `transacao-service` copiando o molde.
- [ ] `ContaClientPort` (application) e `ContaHttpClient` + `ContaClientAdapter` (infra).
- [ ] Adicionar `spring-cloud-starter-circuitbreaker-resilience4j`.
- [ ] Configurar `circuitbreaker`, `retry` e `timelimiter` no YAML.
- [ ] Fallback lançando `ServicoIndisponivelException` → HTTP 503.
- [ ] `ignore-exceptions` para erros de negócio (404 não abre o circuito).
- [ ] Expor `/actuator/circuitbreakers`.

**Pronto quando:** com o `conta-service` desligado, após algumas falhas o `transacao-service` responde 503 **imediatamente** (circuito aberto) e volta sozinho quando o `conta-service` sobe.

---

## Etapa 4 — Mensageria

- [ ] Contratos de evento em `shared/financas-eventos` com envelope (`eventId`, `type`, `version`, `occurredAt`, `payload`).
- [ ] Topologia: exchange `financas.eventos` (topic), DLX `financas.dlx`, filas e DLQs.
- [ ] **Outbox** no `transacao-service`: coleção `outbox` + `OutboxRelay` agendado + publisher confirms.
- [ ] Consumidor no `conta-service` atualizando o saldo, com **idempotência** (`eventos_processados` com índice único em `eventId`).
- [ ] Retry do consumidor com backoff; após N tentativas, vai para a DLQ.

**Pronto quando:** registrar uma transação atualiza o saldo; derrubar o RabbitMQ não perde eventos; enviar a mesma mensagem duas vezes não duplica o saldo.

---

## Etapa 5 — Serviços consumidores

- [ ] `orcamento-service`: domínio `Orcamento` com regras de 80%/100% e consumo de eventos de transação.
- [ ] `notificacao-service`: consome `orcamento.alerta` / `orcamento.excedido` e envia e-mail (MailHog/Mailpit em ambiente local).

**Pronto quando:** estourar um orçamento gera um e-mail visível no Mailpit.

---

## Etapa 6 — Storage e IA

### RustFS (`documento-service`)
- [ ] AWS SDK v2 com endpoint do RustFS e `pathStyleAccess`.
- [ ] Geração de URLs pré-assinadas (PUT e GET).
- [ ] Circuit breaker `rustfs` no adaptador.
- [ ] Tarefa de limpeza de uploads não confirmados.

### Claude (`assistente-ia-service`)
- [ ] Spring AI com Anthropic; chave via `ANTHROPIC_API_KEY`.
- [ ] Prompt de categorização com lista fechada de categorias e saída estruturada.
- [ ] Circuit breaker `claude-api` + time limiter + fallback `NAO_CLASSIFICADA`.
- [ ] Recategorização agendada das pendentes.
- [ ] Projeção local de gastos por mês/categoria para os insights.

**Pronto quando:** transações recebem categoria automaticamente e, com a chave inválida, entram como `NAO_CLASSIFICADA` sem erro para o usuário.

---

## Etapa 7 — Importação de extratos OFX

Depende das etapas 4 (mensageria) e 6 (RustFS e IA).

- [ ] Estudar OFX 1.x (SGML) e 2.x (XML) e escolher o parser; documentar o fluxo em `fluxos.md` e os eventos em `arquitetura.md`.
- [ ] `documento-service`: upload de `.ofx` vinculado a uma conta, pelo mesmo fluxo de URL pré-assinada dos comprovantes.
- [ ] Parser de OFX (FITID, data, valor, descrição, débito/crédito) lendo o arquivo do RustFS com circuit breaker `rustfs`.
- [ ] Evento `StatementParsedV1` publicado via outbox, em lotes.
- [ ] `transacao-service`: consumidor idempotente que registra uma transação por lançamento, com deduplicação por FITID + conta.
- [ ] Acompanhamento da importação (status e contadores de importadas, duplicadas e rejeitadas).
- [ ] `assistente-ia-service`: categorização em lote dos lançamentos importados, só com descrição e valor no prompt.

**Pronto quando:** enviar um OFX gera as transações categorizadas; reenviar o mesmo arquivo não duplica nada; com a IA fora, as transações entram como `NAO_CLASSIFICADA`.

---

## Etapa 8 — Testes

### Pirâmide

```
            ▲   poucos   E2E (fluxo completo com docker compose)
           ▲▲▲           Integração (*IT) — Testcontainers
        ▲▲▲▲▲▲▲▲  muitos  Unitários (*Test) — domain e application
```

| Camada | Ferramenta | O que testar | Exemplo |
|---|---|---|---|
| domain | JUnit 5 | Regras de negócio, invariantes | `Valor` não aceita negativo; `Transacao` não pode ser estornada duas vezes |
| application | JUnit 5 + Mockito | Orquestração do caso de uso, chamadas às portas | Se a conta não existe, não salva nem publica evento |
| infra / persistência | Testcontainers (MongoDB) | Mapeamento, UUID, índices, consultas | UUID salvo como binário subtipo 4 |
| infra / mensageria | Testcontainers (RabbitMQ) | Publicação, consumo, DLQ, idempotência | Mesma mensagem 2x → um único efeito |
| infra / storage | Testcontainers (`GenericContainer` RustFS) | Upload/download por URL pré-assinada | Objeto existe após PUT |
| infra / clientes + CB | WireMock | Circuito abre, fallback, retry | 10 respostas 500 → estado `OPEN` |
| infra / IA | Mock do `ChatModel` | Prompt montado, parse da resposta, fallback | Categoria inválida → `NAO_CLASSIFICADA` |
| arquitetura | ArchUnit | Dependências entre camadas | `domain` não depende de `org.springframework..` |

### Testcontainers com `@ServiceConnection`

```java
@TestConfiguration(proxyBeanMethods = false)
public class ContainersConfig {

    @Bean @ServiceConnection
    MongoDBContainer mongo() {
        return new MongoDBContainer("mongo:8");
    }

    @Bean @ServiceConnection
    RabbitMQContainer rabbit() {
        return new RabbitMQContainer("rabbitmq:4-management");
    }
}
```

### Testando o circuit breaker

```java
@Test
void deveAbrirCircuitoAposFalhasEUsarFallback() {
    wiremock.stubFor(get(urlPathMatching("/contas/.*")).willReturn(serverError()));

    for (int i = 0; i < 10; i++) {
        assertThrows(ServicoIndisponivelException.class, () -> adapter.buscar(UUID.randomUUID()));
    }

    assertThat(registry.circuitBreaker("conta-service").getState())
            .isEqualTo(CircuitBreaker.State.OPEN);
}
```

### Regras de camada com ArchUnit

```java
@AnalyzeClasses(packages = "br.com.finance.transacao")
class RegrasDeCamadasTest {

    @ArchTest
    static final ArchRule camadas = layeredArchitecture().consideringAllDependencies()
            .layer("Domain").definedBy("..domain..")
            .layer("Application").definedBy("..application..")
            .layer("Infra").definedBy("..infra..")
            .whereLayer("Infra").mayNotBeAccessedByAnyLayer()
            .whereLayer("Application").mayOnlyBeAccessedByLayers("Infra")
            .whereLayer("Domain").mayOnlyBeAccessedByLayers("Application", "Infra");

    @ArchTest
    static final ArchRule dominioSemSpring = noClasses().that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAPackage("org.springframework..");
}
```

### Metas

- Cobertura de linhas ≥ 80% em `domain` e `application` (JaCoCo falha o build abaixo disso).
- Todo adaptador com circuit breaker tem teste de **circuito aberto** e de **fallback**.
- Testes unitários rodando em menos de 10s por serviço.

**Pronto quando:** `./mvnw verify` passa com Docker ligado e `./mvnw test` passa sem Docker.

---

## Etapa 9 — Observabilidade

- [ ] Starter OpenTelemetry do Spring Boot; exportar traces via OTLP para o Collector.
- [ ] Propagação de `traceparent` nas mensagens do RabbitMQ.
- [ ] Logs em JSON com `traceId` e `spanId`.
- [ ] Prometheus coletando `/actuator/prometheus` de cada serviço.
- [ ] Dashboards: visão geral (RED: requisições, erros, duração), circuit breakers e filas.
- [ ] Alertas: circuito aberto > 2 min, DLQ > 0, p95 > 1s.

**Pronto quando:** no Jaeger aparece um trace único que vai do gateway até o `notificacao-service`.

---

## Etapa 10 — Gateway e segurança

- [ ] `api-gateway` com Spring Cloud Gateway: rotas, CORS e rate limit.
- [ ] Autenticação OAuth2/OIDC (ex.: Keycloak em container) com validação de JWT no gateway.
- [ ] Repasse do `usuarioId` para os serviços; cada consulta filtra pelos dados do próprio usuário.
- [ ] Segredos apenas por variável de ambiente.

---

## Etapa 11 — Rumo à produção

- [ ] Imagens Docker por serviço (multi-stage ou `spring-boot:build-image`).
- [ ] Pipeline de CI: build → `test` → `verify` → análise estática → imagem.
- [ ] Perfil `prod`: amostragem de traces reduzida, logs em nível INFO, limites de recurso.
- [ ] Health checks de `liveness` e `readiness`.
- [ ] Backup do MongoDB e política de ciclo de vida no bucket do RustFS.
