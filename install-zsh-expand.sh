#!/bin/bash 
mkdir -p ~/.config/zsh/plugins

if [ -d ~/.config/zsh/plugins/zsh-expand/.git ]; then
  git -C ~/.config/zsh/plugins/zsh-expand pull --ff-only
else
  git clone https://github.com/MenkeTechnologies/zsh-expand.git ~/.config/zsh/plugins/zsh-expand
fi

