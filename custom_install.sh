#!/bin/bash
#Script executes these commands with some safeguards in place in case it fails:
# git clone https://github.com/ssi-dk/serum_readfilter
# cd serum_readfilter
# pip install .

#ENV_NAME=$1

GIT_REPO=https://github.com/ssi-dk/serum_readfilter
REPO_FOLDER=serum_readfilter

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR # avoiding small edge case where bashrc sourcing changes your directory

function exit_function() {
  echo "To rerun use the command:"
  echo "bash -i $SCRIPT_DIR/custom_install.sh $ENV_NAME"
  exit 1
}

CONDA_BASE=$(conda info --base)
source $CONDA_BASE/etc/profile.d/conda.sh

# if ! (conda env list | grep "$ENV_NAME")
# then
#   echo "Conda environment specified is not found"
#   exit_function
# else
#   conda activate $ENV_NAME
# fi

if test -d "$SCRIPT_DIR/$REPO_FOLDER"
then
  echo "$SCRIPT_DIR/$REPO_FOLDER already exists, if you want to overwrite, please remove the old repository folder"
  echo "You can use:"
  echo "rm -rf $SCRIPT_DIR/$REPO_FOLDER"
  exit_function
else
  git --version
  GIT_IS_AVAILABLE=$?
  if [ $GIT_IS_AVAILABLE -eq 0 ]
  then
    echo "#################Cloning repository from $GIT_REPO"
    if ! git clone $GIT_REPO
    then
      echo >&2 "git clone command failed"
      exit_function
    else
      cd $REPO_FOLDER
      echo "#################Installing package using pip"
      if ! pip install .
      then
        echo >&2 "pip install command failed"
        exit_function
      else
        echo "Package successfully installed"
      fi
    fi
  else
    echo "git is not installed"
    echo "You can try installing git and rerunning the script"
    exit_function
  fi
fi

echo "Installation complete"
