# 📚 Documentação do Projeto

Esta pasta reúne a documentação técnica e conceitual do **Gerenciamento de Finanças**.

## Por onde começar

| Se você quer... | Leia |
|---|---|
| Entender o projeto sem termos técnicos | [conceitos.md](conceitos.md#1-o-projeto-explicado-de-forma-simples) |
| Entender como o sistema é dividido | [arquitetura.md](arquitetura.md) |
| Saber onde colocar um arquivo novo | [estrutura-de-pastas.md](estrutura-de-pastas.md) |
| Ver o que acontece quando o usuário faz algo | [fluxos.md](fluxos.md) |
| Saber a ordem de construção do projeto | [etapas.md](etapas.md) |
| Consultar o significado de um termo | [conceitos.md](conceitos.md#3-glossário) |
| Configurar, subir e testar o projeto | [README da raiz](../README.md) |
| Saber como enviar uma alteração (branches e pull requests) | [Fluxo de trabalho](../README.md#fluxo-de-trabalho) |

## Documentos

| Arquivo | Conteúdo |
|---|---|
| [arquitetura.md](arquitetura.md) | Microsserviços, camadas (domain/application/infra), circuit breaker, mensageria, banco, storage, IA e observabilidade |
| [estrutura-de-pastas.md](estrutura-de-pastas.md) | Árvore completa do repositório e de um serviço, com a função de cada pasta |
| [fluxos.md](fluxos.md) | Diagramas dos fluxos principais e dos cenários de falha |
| [etapas.md](etapas.md) | Roteiro de construção, da fundação até a produção |
| [conceitos.md](conceitos.md) | Explicação sem jargão, por que das escolhas e glossário |

## Convenções desta documentação

- Diagramas escritos em **Mermaid**, que aparecem renderizados no GitHub/GitLab.
- Exemplos de código em Java 25 e configuração em YAML.
- Ao mudar a arquitetura, atualize o documento correspondente **no mesmo pull request**.
