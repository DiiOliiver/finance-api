---
paths:
  - "**/src/test/**"
---
# Testes

Complementa o `CLAUDE.md` (ferramenta por camada, cobertura e sufixos já estão lá).

## Escrita
- Estrutura `// dado`, `// quando`, `// então` em cada teste.
- Nome do método em inglês descrevendo o comportamento: `shouldRejectExpenseWithZeroAmount()`, `shouldUseFallbackWhenCircuitIsOpen()`.
- Um comportamento por teste.
- Asserções com AssertJ (`assertThat`, `assertThatThrownBy`). Não misture com `assertEquals` do JUnit.
- Testes parametrizados (`@ParameterizedTest`) para variações da mesma regra.

## Dados
- Use builders e fixtures em `support/fixtures/`. Não repita a montagem de objetos em cada teste.
- Nada de dados aleatórios sem semente. Use `Clock.fixed(...)` para datas.
- Valores monetários sempre como `new BigDecimal("...")`.

## Mockito
- Use `@ExtendWith(MockitoExtension.class)` (stubs estritos).
- Mocke só portas (`*Port`). Nunca mocke entidades, value objects ou o próprio caso de uso testado.
- Verifique interações relevantes (`verify(events).publish(...)`), e também as que **não** devem ocorrer (`verifyNoInteractions`).

## Integração
- Um único `ContainersConfig` por serviço, reutilizado por todos os `*IT`. Use imagens com versão fixa.
- Prefira slices: `@WebMvcTest` para controllers, `@DataMongoTest` para persistência. `@SpringBootTest` só para fluxo completo do serviço.
- Limpe coleções e filas no `@BeforeEach`. Testes não dependem da ordem de execução.
- Para fluxos assíncronos (outbox, listeners), use Awaitility. **Nunca** `Thread.sleep`.
- Teste o JSON de cada contrato de evento contra um exemplo em `src/test/resources/events/`.
