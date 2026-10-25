# 🔄 Fluxos

Passo a passo do que acontece no sistema em cada ação importante, incluindo os cenários de falha.

## Sumário

1. [Cadastrar conta](#1-cadastrar-conta)
2. [Registrar transação](#2-registrar-transação)
3. [Categorização automática com IA](#3-categorização-automática-com-ia)
4. [Atualização de orçamento e alerta](#4-atualização-de-orçamento-e-alerta)
5. [Anexar comprovante](#5-anexar-comprovante)
6. [Estornar transação](#6-estornar-transação)
7. [Gerar insights do mês](#7-gerar-insights-do-mês)
8. [Cenários de falha](#8-cenários-de-falha)
9. [Reprocessamento de mensagens (DLQ)](#9-reprocessamento-de-mensagens-dlq)

---

## 1. Cadastrar conta

```mermaid
sequenceDiagram
    actor U as Usuário
    participant GW as api-gateway
    participant CS as conta-service
    participant DB as Mongo (accounts)

    U->>GW: POST /api/accounts
    GW->>GW: valida token e rate limit
    GW->>CS: POST /accounts
    CS->>CS: Account.create(...) gera UUID e valida regras
    CS->>DB: salva conta
    CS-->>GW: 201 Created + id
    GW-->>U: 201 Created
```

**Regras:** nome obrigatório, saldo inicial não negativo, moeda suportada (BRL, USD, EUR).

---

## 2. Registrar transação

Fluxo central do sistema.

```mermaid
sequenceDiagram
    actor U as Usuário
    participant GW as api-gateway
    participant TS as transacao-service
    participant CS as conta-service
    participant DB as Mongo (transactions)
    participant OR as OutboxRelay
    participant MQ as RabbitMQ

    U->>GW: POST /api/transactions
    GW->>TS: POST /transactions
    TS->>CS: GET /accounts/{id} [circuit breaker]
    CS-->>TS: conta ativa
    TS->>TS: Transaction.create(...) aplica regras
    TS->>DB: salva transação + evento na outbox (mesma transação)
    TS-->>GW: 201 Created
    GW-->>U: 201 Created

    Note over OR,MQ: em segundo plano
    OR->>DB: lê outbox pendente
    OR->>MQ: publica transaction.registered
    OR->>DB: marca como enviado
```

**Quem reage ao evento `transaction.registered`:**

| Consumidor | O que faz |
|---|---|
| `conta-service` | Atualiza o saldo da conta |
| `assistente-ia-service` | Categoriza a transação (fluxo 3) |
| `orcamento-service` | Soma ao orçamento do mês (fluxo 4) |

**Etapas em linguagem simples:**

1. O usuário envia a despesa.
2. O sistema confere se a conta existe.
3. A despesa é salva junto com um "recado" para os outros serviços.
4. O usuário recebe a confirmação na hora.
5. Logo depois, o recado é entregue: o saldo é atualizado, a IA categoriza e o orçamento é recalculado.

---

## 3. Categorização automática com IA

```mermaid
sequenceDiagram
    participant MQ as RabbitMQ
    participant IA as assistente-ia-service
    participant CL as API Claude
    participant TS as transacao-service

    MQ->>IA: transaction.registered
    IA->>IA: já processei este eventId? (idempotência)
    IA->>CL: "categorize: 'Mercado Bom Preço' 59,90" [CB + timeout]
    CL-->>IA: {"category": "FOOD", "confidence": 0.94}
    IA->>IA: valida categoria contra a lista permitida
    IA->>MQ: transaction.categorized
    MQ->>TS: transaction.categorized
    TS->>TS: ApplyCategoryUseCase
```

**Se o Claude estiver fora ou lento:**

```mermaid
flowchart LR
    A[transaction.registered] --> B{Circuito claude-api}
    B -- fechado --> C[Chama Claude]
    C -- ok --> D[Publica categoria]
    C -- erro/timeout --> E[Fallback]
    B -- aberto --> E
    E --> F[Publica UNCLASSIFIED]
    F --> G[Agenda recategorização]
    G -- circuito fechou --> C
```

A transação **nunca fica bloqueada** por causa da IA.

---

## 4. Atualização de orçamento e alerta

```mermaid
sequenceDiagram
    participant MQ as RabbitMQ
    participant OS as orcamento-service
    participant DB as Mongo (budgets)
    participant NS as notificacao-service

    MQ->>OS: transaction.categorized (FOOD, 59,90)
    OS->>DB: busca orçamento de FOOD no mês
    OS->>OS: Budget.registerExpense(59,90)
    alt ultrapassou 80%
        OS->>MQ: budget.alert (80%)
    else ultrapassou 100%
        OS->>MQ: budget.exceeded
    end
    OS->>DB: salva
    MQ->>NS: budget.exceeded
    NS->>NS: envia e-mail / push
```

**Regras do domínio `Budget`:**
- Alerta em 80% e 100% do limite, **uma vez por mês por limite**, sem repetir avisos.
- Estorno devolve o valor ao orçamento.

---

## 5. Anexar comprovante

Upload direto para o RustFS com **URL pré-assinada**: o arquivo não passa pelo serviço.

```mermaid
sequenceDiagram
    actor U as Usuário
    participant GW as api-gateway
    participant DS as documento-service
    participant RF as RustFS
    participant MQ as RabbitMQ

    U->>GW: POST /api/receipts (name, type, size, transactionId)
    GW->>DS: POST /receipts
    DS->>DS: valida tipo (pdf/jpg/png) e tamanho (≤ 10 MB)
    DS->>DS: salva metadados com status AWAITING_UPLOAD
    DS->>RF: gera URL pré-assinada de PUT (expira em 5 min) [CB]
    DS-->>U: 201 + uploadUrl
    U->>RF: PUT arquivo na uploadUrl
    U->>GW: POST /api/receipts/{id}/confirm
    GW->>DS: confirmar
    DS->>RF: HEAD objeto (existe? tamanho bate?) [CB]
    DS->>DS: status = AVAILABLE
    DS->>MQ: receipt.attached
```

**Download:** `GET /api/receipts/{id}` devolve uma URL pré-assinada de GET válida por 5 minutos.

**Limpeza:** uma tarefa agendada apaga metadados que ficaram em `AWAITING_UPLOAD` por mais de 24h.

---

## 6. Estornar transação

```mermaid
sequenceDiagram
    actor U as Usuário
    participant TS as transacao-service
    participant MQ as RabbitMQ
    participant CS as conta-service
    participant OS as orcamento-service

    U->>TS: POST /transactions/{id}/reversal
    TS->>TS: transaction.reverse() → erro se já estornada
    TS->>MQ: transaction.reversed (via outbox)
    MQ->>CS: devolve valor ao saldo
    MQ->>OS: devolve valor ao orçamento
```

Transações **nunca são apagadas**, só estornadas. O histórico financeiro fica íntegro.

---

## 7. Gerar insights do mês

```mermaid
sequenceDiagram
    actor U as Usuário
    participant IA as assistente-ia-service
    participant DB as Mongo (ai)
    participant CL as API Claude

    U->>IA: GET /insights?month=2026-10
    IA->>DB: há insight em cache para o mês?
    alt existe e é recente
        DB-->>IA: insight
    else não existe
        IA->>DB: lê resumo agregado (mantido por eventos)
        IA->>CL: gera análise [CB + timeout]
        CL-->>IA: texto + sugestões
        IA->>DB: salva no cache
    end
    IA-->>U: insights
```

- O `assistente-ia-service` mantém sua **própria cópia resumida** dos gastos (por categoria e mês), atualizada pelos eventos. Assim ele não precisa chamar o `transacao-service`.
- Se o circuito estiver aberto, devolve o último insight salvo, ou só os números agregados sem o texto da IA.

---

## 8. Cenários de falha

| Cenário | O que o usuário percebe | O que o sistema faz | Como se recupera |
|---|---|---|---|
| `conta-service` fora do ar | Erro 503 ao lançar transação: "tente novamente em instantes" | Retry 3x, depois o circuito abre e passa a falhar rápido | Circuito testa de novo após 30s e fecha sozinho |
| API do Claude fora ou lenta | Transação aparece como "Não classificada" | Fallback + recategorização agendada | Quando o circuito fecha, as pendentes são recategorizadas |
| RustFS fora do ar | Não consegue anexar comprovante agora; a transação funciona | Circuito `rustfs` abre; erro 503 só no anexo | Usuário tenta de novo depois |
| RabbitMQ fora do ar | Nada: a transação é salva normalmente | Eventos acumulam na outbox | Relay publica tudo quando o RabbitMQ volta |
| Consumidor com erro | Saldo ou orçamento atrasado | Retry da mensagem; após 5 tentativas vai para a DLQ | Correção + reprocessamento da DLQ (seção 9) |
| Mensagem duplicada | Nada | Consumidor reconhece o `eventId` e ignora | — |

### Visualizando a falha

```mermaid
flowchart TD
    R[Requisição] --> T[transacao-service]
    T --> CB{CB conta-service}
    CB -- fechado --> C[conta-service]
    C -- ok --> OK[201 Created]
    C -- falha --> RT{Retry < 3?}
    RT -- sim --> C
    RT -- não --> CNT[conta falha no CB]
    CNT --> FB[Fallback: 503]
    CB -- aberto --> FB
```

---

## 9. Reprocessamento de mensagens (DLQ)

1. Alerta no Grafana: "DLQ com mensagens".
2. Ver a mensagem no painel do RabbitMQ (http://localhost:15672) e o trace no Jaeger pelo `traceparent`.
3. Corrigir a causa (bug, dado inválido etc.).
4. Mover a mensagem de volta para a fila original (shovel ou endpoint administrativo `POST /admin/dlq/{queue}/reprocess`).
5. Como os consumidores são idempotentes, reprocessar é seguro.
