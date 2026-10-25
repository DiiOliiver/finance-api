// Healthcheck do MongoDB no docker-compose (executado com mongosh --file).
// Na primeira execução inicia o replica set de um nó, necessário para as transações (outbox);
// depois só confirma que o nó já é o primário. Código de saída 0 = saudável.
try {
    rs.status();
} catch (e) {
    // Ainda não iniciado. O host é localhost: os serviços rodando na máquina (pela IDE)
    // encontram o membro pela porta publicada; os que rodam em container usam directConnection=true.
    rs.initiate({ _id: 'rs0', members: [{ _id: 0, host: 'localhost:27017' }] });
}

quit(db.hello().isWritablePrimary ? 0 : 1);
