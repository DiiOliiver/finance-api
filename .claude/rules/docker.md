---
paths:
  - "deploy/**"
  - "**/Dockerfile"
  - "**/.dockerignore"
---
# Docker e Docker Compose

## Imagens
- Versões sempre fixas (`mongo:8.0`, `rabbitmq:4.1-management`). Nunca `latest`.
- Ao atualizar uma versão no Compose, atualize também a imagem usada nos `ContainersConfig` dos testes.

## Dockerfile dos serviços
- Multi-stage: estágio de build com JDK 25 + Maven Wrapper; estágio final com `eclipse-temurin:25-jre`.
- Use jar em camadas (`java -Djarmode=tools -jar app.jar extract --layers`) para aproveitar o cache de build.
- Rode como usuário não-root.
- JVM: `-XX:MaxRAMPercentage=75` em vez de `-Xmx` fixo.
- Mantenha `.dockerignore` excluindo `target/`, `.idea/`, `.git/` e `.env`.

## Compose
- Todo serviço tem `healthcheck`. Dependências usam `depends_on` com `condition: service_healthy`.
- Dados em volumes nomeados (`mongo-data`, `rabbitmq-data`, `rustfs-data`).
- Portas publicadas só em `127.0.0.1` (ex.: `127.0.0.1:27017:27017`).
- Credenciais vêm do `.env` (`${MONGO_ROOT_PASSWORD}`). Nenhum segredo escrito no YAML.
- Uma rede única `finance-net` para infra e serviços.
- Toda variável nova é documentada em `deploy/.env.example` e no `README.md`.
