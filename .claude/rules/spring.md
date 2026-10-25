---
paths:
  - "**/infra/**/*.java"
  - "**/src/main/resources/**"
  - "**/*Application.java"
---
# Spring Boot

Complementa o `CLAUDE.md`. Anotações do Spring existem **somente** na camada `infra`.

## Configuração
- Agrupe propriedades próprias em `@ConfigurationProperties` com `record` + `@Validated`, no prefixo `financas.<servico>`. Evite `@Value` espalhado.
- Valores obrigatórios sem padrão em `application.yml`. Os valores de ambiente local ficam em `application-local.yml`.
- Toda variável nova de ambiente entra também em `deploy/.env.example`.

## Beans
- Prefira classes e construtores package-private. Só deixe `public` o que outro pacote precisa.
- `@Component`, `@Service` e `@Repository` só em adaptadores e configs de `infra`.
- Nada de `ApplicationContext.getBean(...)` ou injeção circular.
- Registre um `Clock` como bean (`Clock.systemUTC()`) e injete-o nos casos de uso.

## Transações
- Os casos de uso não levam `@Transactional`. O limite transacional é definido na infra (`TransactionTemplate` ou um decorator do caso de uso em `UseCaseConfig`).
- Mantenha a transação curta: nunca faça chamada HTTP, à IA ou ao RustFS dentro dela.

## Modelo de execução
- Serviços usam Spring MVC (bloqueante) com virtual threads: `spring.threads.virtual.enabled: true`.
- Não use WebFlux, Reactor (`Mono`/`Flux`) ou Mutiny nos serviços.

## Clientes HTTP
- Use HTTP Interfaces (`@HttpExchange` / `@GetExchange`) sobre `RestClient`.
- Configure sempre timeout de conexão e de leitura explícitos. Nunca deixe o padrão infinito.
- A URL base de cada serviço vem de configuração (`finance.clients.<servico>.url`).

## Tarefas agendadas
- `@Scheduled` deve ser seguro com várias instâncias do serviço rodando: reserve o trabalho de forma atômica (ex.: `findAndModify` marcando o documento como `EM_PROCESSAMENTO`) antes de processar.
- Habilite com `@EnableScheduling` numa classe de `infra/config`.

## Actuator
- Em `prod`, exponha apenas `health`, `info` e `prometheus`. Nunca `env`, `beans`, `configprops` ou `heapdump`.
- Separe `liveness` e `readiness` (`management.endpoint.health.probes.enabled: true`).
