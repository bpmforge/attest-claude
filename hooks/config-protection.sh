#!/bin/bash
# Block edits to EXISTING lint/format/type/test config: an agent that cannot pass
# a check will loosen the check. Creating a new config file is allowed.
# Bypass (ticket scope names the file): EXPERTS_ALLOW_CONFIG_EDIT=1
# Hook type: PreToolUse (Write|Edit|MultiEdit). Adapted from affaan-m/ECC (MIT).

[ "$EXPERTS_ALLOW_CONFIG_EDIT" = "1" ] && exit 0
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

case "$(basename "$file_path")" in
  .eslintrc|.eslintrc.js|.eslintrc.cjs|.eslintrc.json|.eslintrc.yml|.eslintrc.yaml|\
  eslint.config.js|eslint.config.mjs|eslint.config.cjs|eslint.config.ts|\
  .prettierrc|.prettierrc.js|.prettierrc.cjs|.prettierrc.json|.prettierrc.yml|.prettierrc.yaml|\
  prettier.config.js|prettier.config.cjs|prettier.config.mjs|biome.json|biome.jsonc|\
  tsconfig.json|tsconfig.base.json|vitest.config.ts|vitest.config.js|vitest.config.mjs|\
  jest.config.js|jest.config.ts|jest.config.cjs|.golangci.yml|.golangci.yaml|.golangci.toml|\
  ruff.toml|.ruff.toml|mypy.ini|.mypy.ini|.flake8|.pylintrc|clippy.toml|.clippy.toml|\
  rustfmt.toml|.rustfmt.toml|deny.toml|.editorconfig|.stylelintrc|.stylelintrc.json)
    echo "BLOCKED: $file_path is lint/format/type/test config. Editing it to make a check pass hides the defect instead of fixing it. Fix the source the check complains about. If the config change IS the task, ask the user to re-run with EXPERTS_ALLOW_CONFIG_EDIT=1." >&2
    exit 2
    ;;
esac
exit 0
