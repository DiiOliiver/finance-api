# CLAUDE.md

Guia para o Claude trabalhar neste repositório. Leia antes de qualquer alteração.

## Projeto

Gerenciamento de finanças pessoais em **microsserviços**, com Arquitetura Hexagonal (**domain / application / infra**) e **circuit breaker** em toda chamada externa.

- Java 25 · Spring Boot 4.1.1 · Maven multi-módulo · configuração em YAML
- MongoDB (IDs UUID) · RustFS (API S3) · RabbitMQ · Claude via Spring AI
- Resilience4j · Docker Compose
- JUnit 5 + Mockito + Testcontainers + WireMock + ArchUnit
- OpenTelemetry + Jaeger + Prometheus + Grafana

Documentação completa em `docs/`. Consulte o documento certo antes de decidir algo:

| Dúvida | Documento |
|---|---|
| Como o sistema é dividido, decisões técnicas | `docs/arquitetura.md` |
| Onde criar um arquivo, nomes de classes | `docs/estrutura-de-pastas.md` |
| O que acontece em cada operação | `docs/fluxos.md` |
| Ordem de construção, estratégia de testes | `docs/etapas.md` |
| Termos e conceitos | `docs/conceitos.md` |

## Comandos

```bash
# Subir infraestrutura local
docker compose -f deploy/docker-compose.yml --env-file deploy/.env up -d

# Build sem testes
./mvnw clean install -DskipTests

# Testes unitários (sem Docker)
./mvnw test
./mvnw -pl <servico> test -Dtest=<Classe>

# Unitários + integração (exige Docker rodando)
./mvnw verify
./mvnw -pl <servico> verify -Dit.test=<Classe>IT

# Rodar um serviço
./mvnw -pl <servico> spring-boot:run -Dspring-boot.run.profiles=local
```

Sempre use `./mvnw`, nunca `mvn`. Após alterar código, rode no mínimo `./mvnw -pl <servico> test`. Se a mudança tocar a camada `infra`, rode também `verify` no serviço.

## Estrutura

Monorepo `finance-api`: um único repositório Git, com os serviços direto na raiz.

```
finance-api/
├── pom.xml                   POM pai e agregador (lista todos os módulos)
├── mvnw, .mvn/               Maven Wrapper único
├── README.md, CLAUDE.md
├── docs/                     documentação
├── deploy/                   docker-compose, .env.example, configs de RabbitMQ, RustFS, OTel, Prometheus, Grafana
├── shared/
│   ├── financas-eventos/     contratos de eventos (records versionados: <Evento>V1)
│   └── financas-commons/     exceções base, Problem Details, tracing do RabbitMQ
├── api-gateway/
├── conta-service/
├── transacao-service/
├── orcamento-service/
├── documento-service/
├── assistente-ia-service/
└── notificacao-service/
```

- Pacote base de cada serviço: `br.com.finance.<servico>` (sem hífen: `assistenteia`), com os subpacotes `domain`, `application` e `infra`.
- Todo módulo novo precisa ser registrado em `<modules>` no `pom.xml` da raiz e ter o `finance-api` como `<parent>`.
- Não crie `.git`, `.gitignore`, `mvnw` ou `.mvn/` dentro dos serviços. Eles existem só na raiz.
- Um serviço nunca depende de outro serviço no Maven. A única dependência permitida entre módulos é com os módulos de `shared/`.

## Git

Fluxo durante o desenvolvimento: **develop → branch → pull request → develop** (detalhes no `README.md`, seção "Fluxo de trabalho").

- Nunca faça commit em `main`, `develop` ou `homol`. O hook `protect-branches.sh` bloqueia.
- Antes de alterar código, crie a branch a partir da `develop` atualizada.
- Pull requests sempre têm a `develop` como base.
- Branches e commits seguem o Conventional Commits; o hook `conventional-commits.sh` bloqueia o que estiver fora do padrão.

| | Formato | Tipos | Exemplo |
|---|---|---|---|
| Branch | `<tipo>/<tarefa>-<descrição>` | `feature`, `refactor`, `bugfix`, `hotfix`, `release`, `chore` | `feature/e2-t1-account-domain` |
| Commit | `<tipo>: <descrição>` | `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore` | `feat: add account domain` |

## Regras de arquitetura (obrigatórias)

### Dependências entre camadas
- Sentido único: `infra → application → domain`. O ArchUnit (`RegrasDeCamadasTest`) quebra o build se for violado.
- **domain** é Java puro: nada de `org.springframework`, `@Document`, Jackson, Lombok, HTTP ou Mongo.
- **application** não conhece tecnologia: sem Spring Data, RabbitMQ, `RestClient`, Resilience4j. Não leva anotações do Spring. Os beans dos casos de uso são criados em `infra/config/UseCaseConfig`.
- **infra** não contém regra de negócio. Controllers, listeners e adaptadores só convertem dados e delegam para casos de uso ou portas.

### Domínio
- Regras e invariantes ficam **dentro** das entidades e value objects, com construtores ou fábricas que validam (`Transacao.nova(...)`, `Valor.de(...)`).
- IDs são `UUID` gerados no domínio, nunca pelo banco.
- Dinheiro é `BigDecimal` no Java e `Decimal128` no Mongo. **Nunca use `double` ou `float`.**
- Eventos de domínio são nomeados no passado (`TransacaoRegistrada`).
- Transações não são apagadas, só estornadas.

### Entre serviços
- Um banco por serviço. Nunca acesse a coleção de outro serviço.
- `shared/` contém apenas contratos e utilitários técnicos. Nunca coloque entidades ou regras de negócio ali.
- Prefira eventos a chamadas HTTP. HTTP síncrono só quando a resposta é indispensável naquele momento. Evite cadeias A → B → C.

### Circuit breaker e resiliência
- **Toda** chamada externa (outro serviço, RustFS, API do Claude) fica num adaptador em `infra/` com `@CircuitBreaker` e `fallbackMethod`. Use também `@Retry` e/ou `@TimeLimiter` quando fizer sentido.
- O nome do circuito é o nome do destino: `conta-service`, `rustfs`, `claude-api`.
- A configuração fica em `application.yml` (`resilience4j.*`), herdando `base-config: padrao`.
- Exceções de negócio estendem `NegocioException` e ficam em `ignore-exceptions`, para que um 404 não abra o circuito.
- Fallbacks seguem o padrão já definido:
  - `conta-service` → `ServicoIndisponivelException` (HTTP 503)
  - `claude-api` → `Categoria.NAO_CLASSIFICADA` + reprocessamento
  - `rustfs` → status `PENDENTE_UPLOAD` / 503 apenas na operação de arquivo
- Nunca coloque anotações de resiliência em `application` ou `domain`.

### Mensageria
- Eventos são publicados **via Outbox** (gravação na mesma transação Mongo + `OutboxRelay`). Nunca publique direto no RabbitMQ a partir de um caso de uso.
- Todo consumidor é **idempotente**: registre o `eventId` em `eventos_processados`.
- Use o envelope padrão (`eventId`, `type`, `version`, `occurredAt`, `traceparent`, `payload`).
- Ao mudar um contrato de forma incompatível, crie uma nova versão (`V2`) em vez de alterar a `V1`.
- Nomes: exchange `financas.eventos` (topic), routing key `<agregado>.<evento>`, fila `<servico-consumidor>.<evento>`, com DLQ.

### MongoDB
- A entidade de domínio e o documento são classes diferentes (`Transacao` ≠ `TransacaoDocument`), ligadas por um mapper.
- UUID com `representation.uuid: standard`.
- Índices criados por changeset do Mongock em `infra/persistence/mongo/migration/`, não por `auto-index-creation`.

### RustFS
- Acesso via AWS SDK v2 com `pathStyleAccess = true`.
- Upload e download por **URL pré-assinada**. Arquivos não trafegam pelo serviço.
- Chave do objeto: `{usuarioId}/{ano}/{mes}/{uuid}.{ext}`.

### IA (Claude)
- Só o `assistente-ia-service` chama a API da Anthropic, via Spring AI.
- Peça saída estruturada (JSON) e valide contra a lista fechada de categorias.
- Nunca envie dados pessoais (nome do titular, número de conta) no prompt.
- Prompts ficam em `src/main/resources/prompts/`.

### Configuração
- Somente YAML (`application.yml` + `application-{local,test,prod}.yml`). Nada de `.properties`.
- Segredos sempre via variável de ambiente (`${ANTHROPIC_API_KEY}`). Nunca escreva credenciais em arquivos versionados, nem faça commit do `.env`.

## Convenções de código

- Use `record` para DTOs, commands, eventos e value objects simples.
- Injeção por construtor, nunca `@Autowired` em campo.
- Erros HTTP no formato Problem Details (RFC 9457), via `ProblemDetailsHandler` do commons.
- Logs estruturados, sem dados sensíveis, sem `System.out`.
- Código em **inglês** (classes, métodos, variáveis, mensagens de log e de exceção); apenas comentários em **português**. Detalhes e equivalência dos nomes legados em `.claude/rules/idioma-codigo.md`.

| Item | Padrão |
|---|---|
| Porta de entrada | `<Acao><Entidade>UseCase` |
| Caso de uso | `<Acao><Entidade>Service` |
| Porta de saída | `<Coisa>Port` |
| Adaptador | `<Coisa>Adapter` |
| Documento Mongo | `<Entidade>Document` |
| Teste unitário / integração | `<Classe>Test` / `<Classe>IT` |

## Testes

Todo código novo vem com teste na camada correspondente:

| Camada | Como testar |
|---|---|
| domain | JUnit puro, sem mocks e sem Spring |
| application | JUnit + Mockito, mockando as portas |
| infra (Mongo, RabbitMQ, RustFS) | Testcontainers com `@ServiceConnection`, classe `*IT` |
| adaptador com circuit breaker | WireMock: testar circuito **aberto** e **fallback** |
| IA | Mock do `ChatModel`; nunca chamar a API real nos testes |

- Cobertura mínima de 80% em `domain` e `application` (JaCoCo).
- Não use `@SpringBootTest` para testar regra de negócio.
- Não desative nem apague testes para fazer o build passar.

## Observabilidade

- Novas integrações devem propagar o trace (HTTP já é automático; RabbitMQ via `traceparent` no header).
- Métricas de negócio relevantes via Micrometer (ex.: `financas.transacoes.registradas`).
- Novo circuito ou fila importante → avaliar painel/alerta em `deploy/grafana/dashboards/`.

## Documentação

Mudou a arquitetura, um fluxo, uma pasta ou um comando? Atualize o arquivo correspondente em `docs/` ou o `README.md` **na mesma alteração**.

## Antes de concluir uma tarefa

- [ ] Camadas respeitadas (ArchUnit passando)
- [ ] Chamadas externas com circuit breaker e fallback
- [ ] Eventos via Outbox e consumidores idempotentes
- [ ] Testes escritos e `./mvnw -pl <servico> verify` passando
- [ ] Nenhum segredo em arquivo versionado
- [ ] `docs/` e `README.md` atualizados, se necessário
