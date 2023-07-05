# Installation Script

## Demo

[![asciicast](https://asciinema.org/a/594774.svg)](https://asciinema.org/a/594774)

## Dependence tools

- curl
- jq
- git

### Automation install

```bash
curl -sSL https://raw.githubusercontent.com/CHIP0K/DevOps-tools/main/git-hooks/gitleaks-setup.sh | bash
```

### Manually install

1) Install [gitleaks](https://github.com/gitleaks/gitleaks)
2) Add the [pre-commit](https://raw.githubusercontent.com/CHIP0K/DevOps-tools/main/git-hooks/gitleaks-check.sh) script: **/path/you/git-hooks/pre-commit**
3) Add the hooks path

```bash
git config --global core.hooksPath /path/you/git-hooks/
```

### Show your Git configurations

```bash
git config --global --list
```