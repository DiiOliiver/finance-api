#!/usr/bin/env bash
# PreToolUse (Bash/PowerShell): nomes de branch e mensagens de commit no padrão do projeto (Conventional Commits).
#   branch: <tipo>/<tarefa>-<descrição>   ex.: feature/e2-t1-account-domain
#   commit: <tipo>: <descrição>           ex.: feat: add account domain
source "$(dirname "$0")/lib.sh"

branch_pattern='^(feature|refactor|bugfix|hotfix|release|chore)/e[0-9]+-t[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$'
commit_pattern='^(feat|fix|docs|style|refactor|perf|test|chore)(\([a-z0-9._-]+\))?!?: [^[:space:]]'
protected='^(main|develop|homol)$'

branch_help="Branch names must follow <type>/<task>-<description>, with type in feature, refactor, bugfix, hotfix, release, chore; task as in the board (e2-t1); description in lowercase kebab-case. Example: feature/e2-t1-account-domain."
commit_help="Commit messages must follow <type>: <description>, with type in feat, fix, docs, style, refactor, perf, test, chore. Example: feat: add account domain."

command=$(json_text command)
[[ -z "$command" ]] && exit 0

# Branch criada no comando: git switch -c/-C/--create, git checkout -b/-B e git branch <nome>.
created_branch() {
    printf '%s\n' "$1" | sed -E 's/(&&|\|\||;|\|)/\n/g' | while IFS= read -r segment; do
        printf '%s\n' "$segment" \
            | grep -oE '(^|[[:space:]])git[[:space:]]+(switch[[:space:]]+(-c|-C|--create|--force-create)|checkout[[:space:]]+(-b|-B)|branch)[[:space:]]+[^-[:space:]][^[:space:]]*' \
            | awk '{ print $NF }'
    done
}

while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    name=${name//[\"\']/}
    if [[ ! "$name" =~ $branch_pattern ]]; then
        block "Invalid branch name '$name'. $branch_help"
    fi
done < <(created_branch "$command")

is_git_commit "$command" || exit 0

# Branch do commit: a atual, salvo se o próprio comando troca de branch antes (aí já foi validada acima).
if ! printf '%s' "$command" | grep -Eq '(^|[[:space:];&|(])git[[:space:]]+(switch|checkout)[[:space:]]'; then
    cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    # main, develop e homol ficam com o protect-branches.sh
    if [[ -n "$branch" && ! "$branch" =~ $protected && ! "$branch" =~ $branch_pattern ]]; then
        block "Current branch '$branch' does not follow the naming convention; rename it before committing (git branch -m <new-name>). $branch_help"
    fi
fi

# Assunto da mensagem: -m/--message, ou a primeira linha de um heredoc usado com -F -.
# Sem mensagem no comando (--no-edit, -C, editor) não há o que validar.
subject=$(printf '%s\n' "$command" | awk '
    function strip(s) {
        if (s ~ /^"/) { sub(/^"/, "", s); sub(/".*$/, "", s) }
        else if (s ~ /^'\''/) { sub(/^'\''/, "", s); sub(/'\''.*$/, "", s) }
        else { sub(/[[:space:]].*$/, "", s) }
        return s
    }
    found { next }
    heredoc != "" { found = 1; print; next }
    /git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)/ {
        line = $0
        # -m "msg", -am "msg", --message="msg"
        if (match(line, /[[:space:]](-[A-Za-z]*m[[:space:]]*|--message(=|[[:space:]]+))/)) {
            found = 1; print strip(substr(line, RSTART + RLENGTH)); next
        }
        if (match(line, /(-F|--file)(=|[[:space:]]+)(-|\/dev\/stdin)/) && match(line, /<<-?[[:space:]]*["'\'']?[A-Za-z_]+/)) {
            heredoc = "yes"
        }
    }
')

if [[ -n "$subject" && ! "$subject" =~ $commit_pattern ]]; then
    block "Invalid commit message '$subject'. $commit_help"
fi

exit 0
