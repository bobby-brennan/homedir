# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi
if [ -f /home/ubuntu/.pentagon/config ]; then
        . /home/ubuntu/.pentagon/config
fi


set -o vi
export EDITOR=vi

git config --global credential.helper 'cache --timeout=3000'

HISTSIZE=5000
HISTFILESIZE=10000
shopt -s histappend

export IP_ADDRESS=$(curl -s http://whatismyip.akamai.com/)

export COLOR_NC='\e[0m' # No Color
export COLOR_WHITE='\e[1;37m'
export COLOR_BLACK='\e[0;30m'
export COLOR_BLUE='\e[0;34m'
export COLOR_LIGHT_BLUE='\e[1;34m'
export COLOR_GREEN='\e[0;32m'
export COLOR_LIGHT_GREEN='\e[1;32m'
export COLOR_CYAN='\e[0;36m'
export COLOR_LIGHT_CYAN='\e[1;36m'
export COLOR_RED='\e[0;31m'
export COLOR_LIGHT_RED='\e[1;31m'
export COLOR_PURPLE='\e[0;35m'
export COLOR_LIGHT_PURPLE='\e[1;35m'
export COLOR_BROWN='\e[0;33m'
export COLOR_YELLOW='\e[1;33m'
export COLOR_GOLD='\e[0;33m'
export COLOR_GRAY='\e[0;30m'
export COLOR_LIGHT_GRAY='\e[0;37m'

if [[ -z "$TMUX" ]] && [ "$SSH_CONNECTION" != "" ]; then
    tmux attach-session -t ssh_tmux || tmux new-session -s ssh_tmux
fi

function parse_git_branch () {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}
function parse_git_status () {
  if ! [ -d ".git" ]; then
    return
  fi
  last_fetch=$(stat -c %Y .git/FETCH_HEAD)
  time_now=$(date +%s)
  if [[ $((time_now - 60)) -gt $((last_fetch)) ]]; then
    GIT_TERMINAL_PROMPT=0 git fetch
  fi
  git rev-parse --git-dir &> /dev/null
  branch="$(parse_git_branch 2> /dev/null)"
  git_status="$(git status 2> /dev/null)"
  status_pattern="working (.*) clean"
  if [[ ! ${git_status} =~ ${status_pattern} ]]; then
    color="${COLOR_RED}"
  else
    color="${COLOR_GREEN}"
  fi
  if [[ -n "$(git remote -v)" ]]; then
    branch_status="$(git rev-list --left-right --count origin/master...$branch)"
    behind_master="$(echo $branch_status | sed '$s/\s\+.*//')"
  else
    echo "$color($branch)${COLOR_YELLOW}?"
    return
  fi
  if [[ -n "$(GIT_TERMINAL_PROMPT=0 git ls-remote origin $branch)" ]]; then
    branch_status="$(GIT_TERMINAL_PROMPT=0 git rev-list --left-right --count origin/$branch...$branch)"
  else
    branch_status="$(GIT_TERMINAL_PROMPT=0 git rev-list --left-right --count master...$branch)"
  fi

  behind_branch="$(echo $branch_status | sed '$s/\s\+.*//')"
  ahead_branch="$(echo $branch_status | sed '$s/.*\s\+//')"
  direction=""
  if [[ ${behind_master} -eq 0 && ${ahead_branch} -eq 0 ]]; then
	direction=""
  elif [[ ${behind_master} -eq 0 && ${ahead_branch} -ne 0 ]]; then
    if [[ ${behind_branch} -eq 0 ]]; then
      direction="${COLOR_LIGHT_BLUE}↑"
    else
      direction="${COLOR_RED}↑"
    fi
  elif [[ ${behind_master} -ne 0 && ${ahead_branch} -eq 0 ]]; then
    if [[ ${branch} == "master" ]]; then
      direction="${COLOR_YELLOW}↓"
    else
      direction="${COLOR_RED}↓"
    fi
  else
	direction="${COLOR_RED}↕"
  fi
  echo "$color($branch)$direction"
}
function set_prompt() {
  exit_code=$?
  git_status=$(parse_git_status)

  prefix="${COLOR_GOLD}${PROMPT_PREFIX}${COLOR_NC}"
  if [ -n "$PROMPT_PREFIX" ]; then
    prefix="$prefix "
  fi
  prefix="${prefix}${COLOR_CYAN}${IP_ADDRESS}${COLOR_NC}"
  pentagon=""
  if [ -n "$INVENTORY" ]; then
    pentagon=" ${COLOR_PURPLE}{$PROJECT - $INVENTORY}"
  fi
  os=$'\uf31b'
  #indicator=$os TODO: unicode screws up tmux
  indicator=^
  indicator_color=$COLOR_GREEN
  if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ]; then
    indicator_color=$COLOR_RED
  fi

  CUR_DIR=`pwd`
  GO_DIR="$GOPATH/src/github.com/reactiveops"
  if [[ $CUR_DIR == $GO_DIR* ]]; then
    CUR_DIR=${CUR_DIR#"$GO_DIR"}
    CUR_DIR="~GO$CUR_DIR"
  fi
  if [[ $CUR_DIR == $HOME* ]]; then
    CUR_DIR=${CUR_DIR#"$HOME"}
    CUR_DIR="~$CUR_DIR"
  fi
  FULL_PROMPT="$indicator_color$indicator $prefix ${CUR_DIR}${git_status}${pentagon}$COLOR_NC\n\$ "
  PS1=$FULL_PROMPT
  history -a
}

export PENTAGON_WORKON_PS1="${PS1}${VENV_PS1}($PROJECT)"
alias cc='cuddlectl'

PROMPT_COMMAND=set_prompt
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\eOA": history-search-backward'
bind '"\eOB": history-search-forward'

alias vi='vim';
alias src='source ~/.bashrc';
alias k='kubectl';
alias kw='watch kubectl';
alias kns='kubectl config set-context $(kubectl config current-context) --namespace '
alias d='sudo docker';
alias dockerstop='d stop $(d ps -a -q)';
alias dockerrm='d rm $(d ps -a -q)';
alias dockerrmi='d rmi $(d images -f "dangling=true" -q)';
alias dockerrmif="d rmi $(d images -q)";
alias dockercleanproc='d ps -aq --no-trunc | xargs sudo docker rm'
alias dockercleanimg='d images -q --filter dangling=true | xargs sudo docker rmi'
alias dockercleanvol='d volume ls -qf dangling=true | xargs -r sudo docker volume rm'
alias dockerclean='dockercleanproc ; dockercleanimg ; dockercleanvol'

function dpush() {
  set -e
  if [ $# -eq 1 ]
    then
      BUILDDIR="."
    else
      BUILDDIR=$2
  fi
  d build -t $1 $BUILDDIR
  d tag $1 quay.io/reactiveops/$1
  d push quay.io/reactiveops/$1
}

alias lsl='ls -lah --color=auto';
alias psa='ps aux';
alias seek='grep --color -re';

alias diskdirs='du --max-depth=1 -c -h | sort -h'

alias bowin='bower install --save';
alias npin='npm install --save';
alias npind='npm install --save-dev';

export GOROOT=/usr/local/go
export GOPATH=$HOME/git/go

export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
export PATH="$PATH:$HOME/Library/Haskell/bin";
export PATH="$PATH:$HOME/.cabal/bin";
export PATH="$PATH:$HOME/.rvm/bin"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/anaconda3/bin"
export PATH="$PATH:$HOME/anaconda2/bin"
export PATH="$PATH:`npm config get prefix`/bin"
export PATH="$PATH:$HOME/.linuxbrew/bin/:/home/linuxbrew/.linuxbrew/bin/"

# For nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

flip() {
  FLIP_SET='set'
  if [ $# -eq 0 ]
    then
      TODIR=0
    else
      TODIR=$1
  fi
  if [[ "$1" == "$FLIP_SET" ]]; then
    FLIP[$2]=$3
  else
    CWD=`pwd`
    cd ${FLIP[$TODIR]}
    flip set 0 $CWD
  fi
}

watchhn() {
  while true; do clear; date;echo;hn top; sleep 360; done
}

ghc() {
  git clone "https://github.com/$1"
}

gitcheck() {
  for dir in ~/git/*; do
    gitstat=`cd $dir && parse_git_status`
    gitstat=$COLOR_NC$gitstat$COLOR_NC
    gitstat=${gitstat//\\[/}
    gitstat=${gitstat//\\]/}
    (cd "$dir" && echo -e "$gitstat: $dir")
  done
}

if [ -f ~/.local-bashrc ]; then
  source ~/.local-bashrc
fi

[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
