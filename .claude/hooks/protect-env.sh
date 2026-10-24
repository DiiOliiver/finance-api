#!/usr/bin/env bash
# PreToolUse: impede alterar arquivos .env, que guardam segredos e nunca são versionados.
# O .env.example é liberado, porque é o modelo documentado sem valores reais.
source "$(dirname "$0")/lib.sh"

# .env, .env.local, .env.prod...; exceto .env.example
is_env_file() {
    local name="${1##*[/\\]}"
    [[ "$name" =~ ^\.env(\..+)?$ && "$name" != ".env.example" ]]
}

message="Changing .env files is not allowed: they hold secrets. Change deploy/.env.example instead and let the user fill in the values."

# Edit, Write, MultiEdit e NotebookEdit
file_path=$(json_field file_path)
[[ -z "$file_path" ]] && file_path=$(json_field notebook_path)
if [[ -n "$file_path" ]] && is_env_file "$file_path"; then
    block "$message"
fi

# Bash e PowerShell: só conta quando o .env é o destino da escrita, não quando é apenas citado
# (uma mensagem de commit que fala de ".env" não pode ser barrada).
# json_text desfaz os escapes do JSON, para que cada linha do comando seja analisada separadamente.
command=$(json_text command)
[[ -z "$command" ]] && exit 0

# Nome de arquivo terminado em .env ou .env.<sufixo>; o caractere seguinte não pode continuar o nome
# (".envrc" não é .env) e é removido depois.
env_token='[^[:space:]"'"'"';&|()<>]*\.env(\.[A-Za-z0-9_-]+)?([^A-Za-z0-9_.-]|$)'
writer='^[[:space:]]*(sudo[[:space:]]+)?(tee|cp|mv|sed[[:space:]]+-i|Copy-Item|Move-Item|Set-Content|Add-Content|Out-File)([[:space:]]|$)'

# Cada comando de um encadeamento (;, &&, ||, |) e cada linha é um trecho.
while IFS= read -r segment; do
    # Redirecionamento: o arquivo logo depois de > ou >>
    targets=$(printf '%s' "$segment" | grep -oE ">>?[[:space:]]*[\"']?${env_token}" | sed -E "s/^>>?[[:space:]]*[\"']?//")
    # Comando que escreve em arquivo no início do trecho: qualquer .env nos argumentos
    if printf '%s' "$segment" | grep -Eq "$writer"; then
        targets+=$'\n'$(printf '%s' "$segment" | grep -oE "$env_token")
    fi
    while IFS= read -r token; do
        token=$(printf '%s' "$token" | sed 's/[^A-Za-z0-9_-]$//')
        if [[ -n "$token" ]] && is_env_file "$token"; then
            block "$message"
        fi
    done <<< "$targets"
done < <(printf '%s\n' "$command" | sed -E 's/(&&|\|\||;|\|)/\n/g')

exit 0
