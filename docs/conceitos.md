# 💡 Conceitos

## Sumário

1. [O projeto explicado de forma simples](#1-o-projeto-explicado-de-forma-simples)
2. [Por que essas escolhas](#2-por-que-essas-escolhas)
3. [Glossário](#3-glossário)

---

## 1. O projeto explicado de forma simples

O sistema ajuda uma pessoa a cuidar do próprio dinheiro: registrar o que entra e o que sai, guardar comprovantes, definir limites de gasto e receber dicas.

Por dentro, ele funciona como uma **empresa com vários departamentos**:

| Departamento | O que faz |
|---|---|
| Recepção (`api-gateway`) | Recebe todo mundo, confere a identidade e encaminha ao departamento certo |
| Contas (`conta-service`) | Sabe quais contas você tem e quanto há em cada uma |
| Lançamentos (`transacao-service`) | Registra cada receita e despesa |
| Orçamento (`orcamento-service`) | Acompanha os limites que você definiu e avisa quando estão perto de estourar |
| Arquivo (`documento-service`) | Guarda os comprovantes |
| Assistente (`assistente-ia-service`) | Usa inteligência artificial para organizar seus gastos e dar sugestões |
| Avisos (`notificacao-service`) | Manda e-mails e notificações |

Os departamentos conversam de dois jeitos:

- **Telefone** (chamada direta): quando é preciso uma resposta na hora. Ex.: "essa conta existe?"
- **Mural de recados** (mensageria): quando basta avisar. Ex.: "acabei de registrar uma despesa". Quem precisar lê o recado e faz sua parte.

---

## 2. Por que essas escolhas

### Por que separar em departamentos (microsserviços)?
Cada departamento cuida de um assunto só. Assim, dá para melhorar um sem mexer nos outros, e se um ficar sobrecarregado, só ele precisa de reforço.

### Por que três camadas dentro de cada departamento?
- **domain** é o **regulamento**: as regras do dinheiro, como "não existe despesa de valor zero". Ele não depende de nenhuma ferramenta.
- **application** é o **gerente**: segue o regulamento e coordena o passo a passo de cada tarefa.
- **infra** são os **funcionários com as ferramentas**: banco de dados, mural de recados, arquivo, IA.

Se amanhã uma ferramenta for trocada, só os funcionários aprendem a nova. O regulamento e o gerente continuam iguais.

### Por que o circuit breaker?
É o **disjuntor da casa**. Se um aparelho dá curto, o disjuntor desarma e o resto da casa continua com luz. Aqui, se a IA ou o arquivo pararem, o sistema para de insistir neles, usa um plano B e segue funcionando. Depois de um tempo, testa de novo e volta ao normal sozinho.

### Por que o mural de recados (RabbitMQ)?
Ninguém precisa ficar esperando o outro atender. Você registra a despesa e já recebe a confirmação. O saldo, o orçamento e a categoria são atualizados logo em seguida.

### Por que guardar o recado junto com a despesa (outbox)?
Para não acontecer de a despesa ser salva e o recado se perder. Os dois são guardados juntos, e um "carteiro" entrega o recado depois, mesmo que o mural tenha ficado fora do ar por um tempo.

### Por que cada departamento tem seu próprio banco?
Para que um não mexa nas gavetas do outro. Cada um é responsável pelos seus dados.

### Por que UUID?
É um número de identificação que pode ser criado em qualquer lugar sem risco de repetir. A despesa já nasce com seu "RG", antes mesmo de ser guardada.

### Por que os comprovantes vão direto para o arquivo (URL pré-assinada)?
O sistema entrega ao usuário uma "chave temporária" do arquivo. O comprovante vai direto para lá, sem ninguém no meio carregando o peso.

### Por que a IA fica num departamento separado?
Para concentrar num só lugar os custos, os limites de uso e os problemas da IA. Se ela falhar, ninguém mais é afetado.

### Por que tantos testes?
As regras são conferidas de forma rápida e isolada. As ferramentas são testadas de verdade, em containers, para não ter surpresa quando o sistema estiver no ar.

### Por que observabilidade?
Com vários departamentos, quando algo dá errado é preciso saber **onde**. Os traces mostram o caminho de cada pedido, e os painéis mostram a saúde do sistema em tempo real.

---

## 3. Glossário

### Arquitetura e padrões

| Termo | O que é |
|---|---|
| **Microsserviço** | Aplicação pequena e independente, com um único assunto de negócio, seu próprio banco e deploy separado |
| **Arquitetura em camadas** | Organizar o código em níveis com responsabilidades distintas |
| **Arquitetura Hexagonal (Ports & Adapters)** | O núcleo de negócio define interfaces (portas) e as tecnologias externas se conectam por adaptadores |
| **Domain** | Camada com as regras de negócio puras, sem framework |
| **Application** | Camada que orquestra os casos de uso usando o domínio e as portas |
| **Infra (Infrastructure)** | Camada com os detalhes técnicos: banco, filas, HTTP, IA, storage |
| **Porta (Port)** | Interface que define o que o núcleo precisa ou oferece, sem dizer como é feito |
| **Porta de entrada (in)** | O que o serviço oferece (casos de uso) |
| **Porta de saída (out)** | O que o serviço precisa do mundo externo (banco, outro serviço, fila) |
| **Adaptador (Adapter)** | Implementação concreta de uma porta usando uma tecnologia |
| **Caso de uso (Use Case)** | Uma ação do sistema do ponto de vista do usuário, ex.: "registrar transação" |
| **Entidade** | Objeto de negócio com identidade própria (ex.: Transação com UUID) |
| **Value Object** | Objeto definido só pelo valor e imutável (ex.: `Valor` = 100 BRL) |
| **Agregado** | Grupo de objetos tratados como uma unidade de consistência, com uma entidade "raiz" |
| **Invariante** | Regra que precisa ser verdadeira sempre (ex.: valor > 0) |
| **Evento de domínio** | Registro de algo que aconteceu no negócio, nomeado no passado (`TransacaoRegistrada`) |
| **DTO / Command** | Objeto simples só para transportar dados entre camadas |
| **Mapper** | Código que converte um formato de objeto em outro (ex.: Document ↔ Entidade) |
| **Database per service** | Cada microsserviço tem seu banco e nenhum outro acessa diretamente |
| **API Gateway** | Ponto de entrada único que roteia as requisições para os serviços |
| **Projeção** | Cópia local e resumida de dados de outro serviço, mantida atualizada por eventos |
| **Comunicação síncrona** | Chamada que espera a resposta (HTTP) |
| **Comunicação assíncrona** | Envio de mensagem sem esperar resposta (fila) |
| **Consistência eventual** | Os dados ficam corretos em todos os serviços após alguns instantes, não no mesmo milissegundo |
| **Padrão Outbox** | Gravar o evento no mesmo banco e na mesma transação da operação, e publicar depois |
| **Idempotência** | Executar a mesma operação várias vezes produz o mesmo resultado que executar uma vez |
| **Problem Details (RFC 9457)** | Formato padrão de resposta de erro em APIs HTTP |
| **ADR / Decisão de arquitetura** | Registro de uma decisão técnica, seu motivo e alternativas descartadas |

### Resiliência

| Termo | O que é |
|---|---|
| **Resiliência** | Capacidade de o sistema continuar funcionando, mesmo que parcialmente, quando algo falha |
| **Circuit Breaker** | Interrompe chamadas a um serviço que está falhando, evitando efeito cascata |
| **Estado Fechado** | Circuito normal: as chamadas passam |
| **Estado Aberto** | Circuito bloqueando: as chamadas vão direto para o fallback |
| **Estado Meio-aberto** | Algumas chamadas de teste passam para verificar se o serviço voltou |
| **Sliding window** | Janela das últimas N chamadas usada para calcular a taxa de falha |
| **Fallback** | Plano B executado quando a chamada falha ou o circuito está aberto |
| **Retry** | Tentar de novo automaticamente, útil para falhas momentâneas |
| **Backoff exponencial** | Esperar cada vez mais entre as tentativas (200ms, 400ms, 800ms...) |
| **Time Limiter / Timeout** | Tempo máximo de espera por uma resposta |
| **Bulkhead** | Limitar chamadas simultâneas a um recurso para não consumir tudo |
| **Efeito cascata** | Quando a falha de um serviço derruba os que dependem dele |
| **Resilience4j** | Biblioteca Java que implementa circuit breaker, retry, timeout e bulkhead |
| **Spring Cloud Circuit Breaker** | Integração do Spring com o Resilience4j |

### Plataforma e linguagem

| Termo | O que é |
|---|---|
| **Java 25** | Versão LTS da linguagem |
| **Record** | Tipo Java compacto e imutável, ideal para DTOs, eventos e value objects |
| **Virtual Threads** | Threads leves da JVM que aguentam muitas operações de I/O simultâneas |
| **Spring Boot** | Framework que configura e executa aplicações Java com mínimo esforço |
| **Spring Cloud Gateway** | Implementação de API Gateway do ecossistema Spring |
| **Maven** | Ferramenta de build e gerenciamento de dependências Java |
| **Maven multi-módulo** | Projeto pai com vários subprojetos e versões centralizadas |
| **Maven Wrapper (`mvnw`)** | Script que baixa e usa a versão certa do Maven automaticamente |
| **Surefire / Failsafe** | Plugins Maven que rodam testes unitários (`*Test`) e de integração (`*IT`) |
| **JaCoCo** | Mede a cobertura de testes |
| **YAML** | Formato de configuração baseado em indentação (`application.yml`) |
| **Perfil (profile)** | Conjunto de configurações por ambiente: `local`, `test`, `prod` |
| **Actuator** | Expõe endpoints de saúde, métricas e informações da aplicação |
| **Health check** | Verificação automática se o serviço está saudável |
| **Liveness / Readiness** | "Está vivo?" / "Está pronto para receber requisições?" |

### Dados e armazenamento

| Termo | O que é |
|---|---|
| **MongoDB** | Banco NoSQL orientado a documentos (JSON/BSON) |
| **Coleção** | Conjunto de documentos no MongoDB, equivalente a uma tabela |
| **Replica set** | Grupo de instâncias do Mongo; necessário para transações multi-documento |
| **Decimal128** | Tipo numérico decimal exato do Mongo, usado para dinheiro |
| **Mongock** | Ferramenta de migração para MongoDB (índices, ajustes de dados) |
| **UUID** | Identificador único universal de 128 bits, gerado sem depender do banco |
| **UUID representation `standard`** | Formato padrão de gravação de UUID no Mongo (binário subtipo 4) |
| **RustFS** | Object storage open source compatível com a API S3, escrito em Rust |
| **Object Storage** | Armazenamento de arquivos (objetos) acessados por chave |
| **API S3** | Padrão de interface de object storage criado pela AWS |
| **Bucket** | Recipiente que agrupa objetos no object storage |
| **URL pré-assinada** | Link temporário para enviar ou baixar um arquivo sem expor credenciais |

### Mensageria

| Termo | O que é |
|---|---|
| **RabbitMQ** | Message broker que recebe, guarda e entrega mensagens entre serviços |
| **AMQP** | Protocolo de mensagens usado pelo RabbitMQ |
| **Exchange** | Recebe mensagens e decide para quais filas vão |
| **Topic exchange** | Exchange que roteia por padrão de routing key (ex.: `transacao.*`) |
| **Routing key** | "Endereço" da mensagem usado pelo exchange |
| **Fila (Queue)** | Lugar onde as mensagens esperam para ser consumidas |
| **Binding** | Ligação entre exchange e fila |
| **Publisher confirm** | Confirmação do RabbitMQ de que recebeu a mensagem |
| **DLX / DLQ** | Exchange e fila para onde vão mensagens que falharam repetidamente |
| **Envelope de evento** | Estrutura padrão da mensagem: id, tipo, versão, data, payload |

### IA

| Termo | O que é |
|---|---|
| **LLM** | Modelo de linguagem de grande porte: IA que entende e gera texto |
| **Claude** | LLM da Anthropic, usado para categorizar transações e gerar insights |
| **Spring AI** | Biblioteca do Spring para integrar LLMs de forma padronizada |
| **Prompt** | Instrução enviada ao modelo |
| **Saída estruturada** | Pedir ao modelo uma resposta em formato fixo (JSON) para validar no código |
| **Temperatura** | Controla a variação das respostas; 0 = mais previsível |

### Containers

| Termo | O que é |
|---|---|
| **Docker** | Empacota a aplicação e dependências em containers isolados |
| **Imagem** | "Molde" a partir do qual o container é criado |
| **Container** | Instância em execução de uma imagem |
| **Volume** | Armazenamento que sobrevive à remoção do container |
| **Docker Compose** | Sobe vários containers juntos a partir de um arquivo YAML |

### Testes

| Termo | O que é |
|---|---|
| **Teste unitário** | Testa uma parte isolada do código, sem dependências externas |
| **Teste de integração** | Testa a aplicação com componentes reais (banco, fila) |
| **Teste E2E** | Testa o fluxo completo, do início ao fim |
| **Pirâmide de testes** | Muitos testes unitários, menos de integração, poucos E2E |
| **JUnit 5** | Framework padrão de testes em Java |
| **Mockito** | Cria objetos falsos (mocks) que simulam dependências |
| **Mock** | Objeto simulado com respostas pré-definidas |
| **Testcontainers** | Sobe containers Docker reais durante os testes |
| **`@ServiceConnection`** | Liga automaticamente o container de teste à configuração do Spring |
| **WireMock** | Simula um serviço HTTP externo, útil para forçar falhas |
| **ArchUnit** | Testa regras de arquitetura (quem pode depender de quem) |
| **Fixture** | Dado de exemplo reutilizado nos testes |

### Observabilidade

| Termo | O que é |
|---|---|
| **Observabilidade** | Capacidade de entender o que acontece dentro do sistema por traces, métricas e logs |
| **OpenTelemetry (OTel)** | Padrão aberto para coletar traces, métricas e logs |
| **OTLP** | Protocolo de envio de dados do OpenTelemetry |
| **OTel Collector** | Recebe a telemetria e encaminha para Jaeger, Prometheus etc. |
| **Trace** | Caminho completo de uma requisição por todos os serviços |
| **Span** | Cada etapa individual dentro de um trace |
| **`traceparent`** | Cabeçalho padrão (W3C) que carrega o ID do trace entre serviços |
| **Amostragem (sampling)** | Percentual de requisições que geram trace |
| **Jaeger** | Ferramenta para visualizar e pesquisar traces |
| **Micrometer** | Biblioteca que gera métricas na aplicação Spring |
| **Prometheus** | Banco de séries temporais que coleta métricas periodicamente |
| **PromQL** | Linguagem de consulta do Prometheus |
| **Grafana** | Dashboards e alertas sobre métricas e traces |
| **Métricas RED** | Rate (requisições), Errors (erros), Duration (tempo) |
| **p95** | Tempo abaixo do qual estão 95% das requisições |

### Segurança

| Termo | O que é |
|---|---|
| **OAuth2 / OIDC** | Padrões de autorização e autenticação |
| **JWT** | Token assinado que carrega a identidade do usuário |
| **Keycloak** | Servidor de identidade open source |
| **Rate limit** | Limite de requisições por período para evitar abuso |
| **CORS** | Regras que dizem quais sites podem chamar a API pelo navegador |
