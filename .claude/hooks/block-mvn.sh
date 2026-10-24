#!/usr/bin/env bash
# PreToolUse (Bash/PowerShell): o projeto usa sempre o Maven Wrapper, nunca o mvn instalado na máquina.
source "$(dirname "$0")/lib.sh"

command=$(json_field command)

# "mvn" como comando isolado: início da linha ou depois de espaço, ;, &, |, ( ou crase.
# ./mvnw, mvnw.cmd e caminhos como /opt/maven/bin/mvn não casam.
if printf '%s' "$command" | grep -Eq '(^|[[:space:];&|(`])mvn(\.cmd)?([[:space:];&|)]|$)'; then
    block "Use ./mvnw instead of mvn (CLAUDE.md: always use the Maven Wrapper)."
fi

exit 0
