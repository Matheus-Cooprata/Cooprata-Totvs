# cooprata

## Setup

Ative os hooks locais após clonar:
```bash
git config core.hooksPath .githooks
chmod -R +x .githooks
```

## Fluxo de trabalho

```
feature branch → PR para main (Squash and Merge)
```

1. `./.githooks/scripts/new-feature.sh minha-task` — cria a branch
2. Commits no padrão [Conventional Commits](https://www.conventionalcommits.org)
3. Abra o PR e preencha `.github/pull_request_template.md`

## Git Hooks

| Hook | Ação |
|---|---|
| **pre-commit** | Bloqueia commits em `main`, barra arquivos sensíveis, roda linting |
| **commit-msg** | Valida Conventional Commits |
| **pre-push** | Bloqueia push em `main`, roda os testes |

> Linting e testes são opcionais: se a ferramenta não estiver instalada, o hook avisa e continua.

## Release

A cada merge em `main` o workflow `auto-release.yml` calcula a versão, atualiza o `CHANGELOG.md` e publica a GitHub Release automaticamente.

| Commit | Bump |
|---|---|
| `BREAKING CHANGE` / `!:` | major |
| `feat:` | minor |
| `fix:`, `chore:`, outros | patch |

Para testar localmente:
```bash
./.githooks/scripts/release.sh --dry-run  # preview
./.githooks/scripts/release.sh            # release efetiva
```
