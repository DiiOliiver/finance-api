#!/usr/bin/env bash
# PreToolUse (Bash/PowerShell): main, develop e homol nunca recebem commit direto.
# O trabalho é feito numa branch criada a partir da develop e volta por pull request.
source "$(dirname "$0")/lib.sh"

protected='^(main|develop|homol)$'

command=$(json_field command)
is_git_commit "$command" || exit 0

# Se o mesmo comando troca ou cria branch antes do commit, a branch atual ainda não é a do commit.
if printf '%s' "$command" | grep -Eq '(^|[[:space:];&|(])git[[:space:]]+(switch|checkout)[[:space:]]'; then
    exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0

if [[ "$branch" =~ $protected ]]; then
    block "Committing directly to '$branch' is not allowed. Create a branch from develop (git switch -c <type>/<task> develop), commit there and open a pull request to develop."
fi

exit 0
