# Dots

```sh
# base url
RAW_URL=https://raw.githubusercontent.com/xnorkl/Dots/main
```

## single file

```sh
# overwrites existing file
curl -fsSL --create-dirs -o ~/.tmux.conf $RAW_URL/.tmux.conf
```

## shell, git, tmux

```sh
for f in .zshrc .gitconfig .tmux.conf .config/starship.toml .config/git/ignore; do
  curl -fsSL --create-dirs -o ~/$f $RAW_URL/$f
done
```

## editors, terminal, tools

```sh
for f in .config/nvim/init.lua .config/ghostty/config .config/htop/htoprc \
         .config/mdless/config.yml .config/mdless/mdless.theme; do
  curl -fsSL --create-dirs -o ~/$f $RAW_URL/$f
done
```

## glow

```sh
# linux
curl -fsSL --create-dirs -o ~/.config/glow/glow.yml $RAW_URL/.config/glow/glow.yml
# macos
curl -fsSL --create-dirs -o ~/Library/Preferences/glow/glow.yml $RAW_URL/.config/glow/glow.yml
```

## ssh

```sh
curl -fsSL --create-dirs -o ~/.ssh/config $RAW_URL/.ssh/config
chmod 700 ~/.ssh && chmod 600 ~/.ssh/config
```

## claude code

```sh
for f in .claude/CLAUDE.md .claude/settings.json \
         .claude/hooks/trunk-guard.sh .claude/hooks/complexity-precommit.sh .claude/hooks/hx-hook-lib.sh; do
  curl -fsSL --create-dirs -o ~/$f $RAW_URL/$f
done
chmod +x ~/.claude/hooks/*.sh
```

## local overrides

```sh
# machine specific, never committed
touch ~/.zshrc.local ~/.gitconfig.local ~/.ssh/config.local
chmod 600 ~/.ssh/config.local
```

## clone

```sh
git clone git@github.com:xnorkl/Dots.git && cd Dots
# enable secret scanning hooks
git config core.hooksPath .githooks
```
