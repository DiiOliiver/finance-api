#!/usr/bin/env bash
# PreToolUse (Bash/PowerShell): antes de um "git commit", roda os testes unitários dos módulos alterados.
# Se algum falhar, o commit é bloqueado. Usa "test" (sem Docker), o mínimo pedido no CLAUDE.md.
source "$(dirname "$0")/lib.sh"

command=$(json_field command)

is_git_commit "$command" || exit 0

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}" || exit 0

services=(api-gateway conta-service transacao-service orcamento-service documento-service assistente-ia-service notificacao-service)

# Arquivos alterados: no stage e fora dele, porque o comando pode fazer "git add" antes do commit ou usar -a.
changed=$( { git diff --cached --name-only; git diff --name-only; git ls-files --others --exclude-standard; } | sort -u)

# POM raiz ou shared/ afetam todos os serviços; fora isso, só os serviços cujos arquivos mudaram.
modules=()
if printf '%s\n' "$changed" | grep -Eq '^(pom\.xml|shared/)'; then
    modules=("${services[@]}")
else
    for service in "${services[@]}"; do
        if printf '%s\n' "$changed" | grep -q "^$service/"; then
            modules+=("$service")
        fi
    done
fi

# Só documentação ou configuração fora dos módulos: nada para testar.
[[ ${#modules[@]} -eq 0 ]] && exit 0

log=$(mktemp)
trap 'rm -f "$log"' EXIT

# Linhas úteis do log do Maven: testes que falharam e erros, sem o rodapé padrão de ajuda.
failure_summary() {
    grep -E '\[ERROR\]|Tests run:.*(Failures: [1-9]|Errors: [1-9])' "$1" \
        | grep -vE 'To see the full stack trace|Re-run Maven|For more information|\[Help 1\]|^\[ERROR\][[:space:]]*$' \
        | head -n 30
}

# O reactor da raiz só funciona com todos os <module> do pom.xml presentes; se faltar algum
# (ex.: shared/ antes da E0·T3), cada serviço é testado sozinho com o wrapper da raiz.
reactor_ready=true
while read -r declared; do
    [[ -f "$declared/pom.xml" ]] || reactor_ready=false
done < <(grep -oE '<module>[^<]+</module>' pom.xml | sed -E 's#</?module>##g')

if $reactor_ready; then
    selected=$(IFS=,; printf '%s' "${modules[*]}")
    if ! bash ./mvnw -B -q -pl "$selected" -am test >"$log" 2>&1; then
        block "Commit blocked: unit tests failed in ${selected}.
$(failure_summary "$log")"
    fi
else
    failed=()
    for module in "${modules[@]}"; do
        if ! bash ./mvnw -B -q -f "$module/pom.xml" test >>"$log" 2>&1; then
            failed+=("$module")
        fi
    done
    if [[ ${#failed[@]} -gt 0 ]]; then
        block "Commit blocked: unit tests failed in ${failed[*]}.
$(failure_summary "$log")"
    fi
fi

exit 0
