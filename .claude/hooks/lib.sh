#!/usr/bin/env bash
# Funções comuns dos hooks do Claude Code. Usa só grep e sed para não depender de jq, Node ou Python.

# Lê o JSON do hook (stdin) uma única vez.
HOOK_INPUT=$(cat)

# Devolve o valor de um campo string do JSON de entrada (primeira ocorrência), sem as aspas.
# Basta para casar padrões; escapes como \" e \\ são mantidos.
json_field() {
    printf '%s' "$HOOK_INPUT" \
        | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"\(\\\\.\|[^\"\\\\]\)*\"" \
        | head -n 1 \
        | sed "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//; s/\"\$//"
}

# Como json_field, mas desfaz os escapes do JSON (\n vira quebra de linha, \" vira aspas).
json_text() {
    json_field "$1" | sed 's/\\n/\n/g; s/\\t/\t/g; s/\\"/"/g; s/\\\\/\\/g'
}

# Verdadeiro se o comando roda "git commit", inclusive com opções antes do subcomando (git -c k=v commit).
is_git_commit() {
    printf '%s' "$1" | grep -Eq '(^|[[:space:];&|(])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)'
}

# Bloqueia a chamada da ferramenta: exit 2 faz o Claude Code cancelar e repassar a mensagem ao Claude.
block() {
    printf '%s\n' "$1" >&2
    exit 2
}
