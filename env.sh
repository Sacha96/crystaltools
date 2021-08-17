#!/usr/bin/env bash
# set -x

#2 arguments
#e.g. git_get github.com/crystaluniverse crystaltools 
#return is in $CDIR
function git_get {
    # echo "git get for account:'$1' repo:'$2'"
    if [[ -d "$DIR_CODE/$2" ]]
    then
        pushd $DIR_CODE/$2 2>&1 >> /dev/null
        git pull
        popd 2>&1 >> /dev/null
    else
        pushd $DIR_CODE 2>&1 >> /dev/null
        git clone https://$1/$2
        popd 2>&1 >> /dev/null
    fi
    CDIR="$DIR_CODE/$2"
}

#means we are in gitpod
if [[ -d "/workspace" ]]
then
    export HOME="/workspace"
    export DIR_BASE="/workspace/publisher"    
else
    export DIR_BASE="$HOME/.publisher"
fi

export DIR_BUILD="/tmp"
export DIR_CODE="$HOME/code"
export DIR_CODEWIKI="$HOME/codewiki"
export DIR_CODE_INT="$HOME/_code"
export DIR_BIN="/usr/local/bin"

mkdir -p $DIR_CODE
mkdir -p $DIR_CODE_INT
mkdir -p $DIR_BUILD


if [[ -d "/workspace/crystaltools" ]]
then
    #this means we are booting in gitpod from crystal tools itself
    export DIR_CT="/workspace/crystaltools"
else    
    export DIR_CT="$HOME/code/crystaltools"
    #get the crystal tools
    git_get github.com/crystaluniverse crystaltools
fi





# git config --global pull.rebase false

export PATH=$DIR_CT/scripts:$PATH

