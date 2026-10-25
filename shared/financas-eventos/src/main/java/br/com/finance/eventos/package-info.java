/**
 * Contratos dos eventos trocados entre os serviços pelo RabbitMQ.
 *
 * <p>Cada evento é um record versionado (sufixo {@code V1}, {@code V2}...) e trafega dentro do
 * envelope padrão. Mudança incompatível gera uma nova versão; a anterior não é alterada.
 * Aqui só entram contratos: nada de entidades nem regras de negócio.
 */
package br.com.finance.eventos;
