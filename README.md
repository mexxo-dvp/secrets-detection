[UA](#ua) | [EN](#en)
<a id="ua"></a>
# Gitleaks Pre-Commit (Go) {#ua}

Легкий pre-commit хук на Go, який автоматично запускає **gitleaks** перед комітом і блокує потрапляння секретів у репозиторій. Працює крос‑платформенно, уміє **автовстановлювати gitleaks** залежно від ОС, має перемикач через `git config`, і містить правило, наприклад для **Telegram Bot Token**. Файл правил **не містить реальних секретів** — лише патерни (regex).

## Ключові можливості

* Автозапуск у `pre-commit`: сканує **staged** зміни (`gitleaks protect --staged --redact --exit-code 1`).
* **Автоінсталяція gitleaks**: `brew` (macOS/Linux), `apt` (Linux), `choco` (Windows), `go install`, і fallback **curl | sh** → `./bin`.
* **Увімк./вимк.** через `git config gitleaks.precommit.enable` (за замовчуванням `true`).
* Кастомні правила в `tools/gitleaks/config.toml` (включно з патерном для Telegram токена).
* (Опційно) **CI GitHub Actions** для скану push/PR.

## Структура

```
tools/gitleaks/
  ├─ config.toml
  ├─ Makefile
  ├─ cmd/gitleaks-precommit/main.go
  └─ scripts/install_gitleaks.sh
# (опційно)
.github/workflows/gitleaks.yml
```

## Інсталяція локального pre-commit

```bash
make -C tools/gitleaks install
make -C tools/gitleaks enable
```

> Хук встановить бінарник `.git/hooks/gitleaks-precommit` і тонкий шімач `.git/hooks/pre-commit`.

## Швидка перевірка

**Smoke (без секретів):**

```bash
git commit --allow-empty -m "chore: smoke pre-commit (no secrets)"
```

**Позитивний тест (має заблокувати коміт):**

```bash
echo 'FAKE-TELEGRAM-TOKEN' > demo.env
git add demo.env
git commit -m "test: add demo token"  # очікуємо блокування
### Приклад виводу (успішний коміт без секретів)
```
```
    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks
```
```
11:18AM INF 0 commits scanned.
11:18AM INF scan completed in 51.7ms
11:24AM WRN leaks found: 1
❌ gitleaks found potential secrets in staged changes. Commit rejected.
```

---

# прибирання
```bash
git restore --staged demo.env && rm -f demo.env
```

## Ручний скан (без коміту)

```bash
make -C tools/gitleaks scan
# або
gitleaks detect --redact --exit-code 1 --config tools/gitleaks/config.toml
```

## Вимкнути / увімкнути

```bash
git config --local gitleaks.precommit.enable false
git config --local gitleaks.precommit.enable true
```

## (Опційно) CI GitHub Actions

`.github/workflows/gitleaks.yml`

```yaml
name: security - gitleaks
on:
  pull_request:
    branches: ["main", "develop"]
  push:
    branches: ["main"]
permissions:
  contents: read

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_CONFIG: tools/gitleaks/config.toml
```

## Ліцензія

MIT

---
<a id="en"></a>
[UA](#ua) | [EN](#en)
# Gitleaks Pre-Commit (Go) {#en}

A lightweight Go pre-commit hook that runs **gitleaks** before each commit to block secrets from entering your repository. Cross‑platform, **auto‑installs gitleaks** per OS, toggleable via `git config`, for example, let's take **Telegram bot token** rule. The rules file stores **no real secrets**—only regex patterns.

## Key features

* Automatic `pre-commit` execution on **staged** changes (`gitleaks protect --staged --redact --exit-code 1`).
* **Auto‑install**: `brew` (macOS/Linux), `apt` (Linux), `choco` (Windows), `go install`, plus **curl | sh** fallback → `./bin`.
* **Enable/disable** via `git config gitleaks.precommit.enable` (default `true`).
* Custom rules in `tools/gitleaks/config.toml` (including a Telegram token regex).
* Optional **GitHub Actions CI** to scan on push/PR.

## Layout

```
tools/gitleaks/
  ├─ config.toml
  ├─ Makefile
  ├─ cmd/gitleaks-precommit/main.go
  └─ scripts/install_gitleaks.sh
# (optional)
.github/workflows/gitleaks.yml
```

## Local install

```bash
make -C tools/gitleaks install
make -C tools/gitleaks enable
```

## Quick check

**Smoke (no secrets):**

```bash
git commit --allow-empty -m "chore: smoke pre-commit (no secrets)"
```

**Positive (should block):**

```bash
echo 'FAKE-TELEGRAM-TOKEN' > demo.env
git add demo.env
git commit -m "test: add demo token"  # expected block
```

### Sample output (no secrets)

```
    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks
```
```
11:18AM INF 0 commits scanned.
11:18AM INF scan completed in 51.7ms
11:24AM WRN leaks found: 1
❌ gitleaks found potential secrets in staged changes. Commit rejected.
```

# cleanup
```bash
git restore --staged demo.env && rm -f demo.env
```

## Manual scan

```bash
make -C tools/gitleaks scan
# or
gitleaks detect --redact --exit-code 1 --config tools/gitleaks/config.toml
```

## Toggle

```bash
git config --local gitleaks.precommit.enable false
git config --local gitleaks.precommit.enable true
```

## License

MIT
