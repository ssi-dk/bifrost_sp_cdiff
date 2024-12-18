#!/bin/bash
#Script executes these commands with some safeguards in place in case it fails:
# git clone https://github.com/ssi-dk/serum_readfilter
# cd serum_readfilter
# pip install .

ENV_NAME=$1
echo "Environment $ENV_NAME and $1"


GIT_REPO=https://github.com/ssi-dk/serum_readfilter
REPO_FOLDER="serum_readfilter"
SUBMODULE_PATH="bifrost_sp_cdiff/cdiff_fbi"  # Path to the submodule

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR # avoiding small edge case where bashrc sourcing changes your directory

function exit_function() {
  echo "To rerun use the command:"
  echo "bash -i $SCRIPT_DIR/custom_install.sh $ENV_NAME"
  exit 1
}


#CONDA_BASE=$(conda info --base)
#source $CONDA_BASE/etc/profile.d/conda.sh
#conda env list | grep "$ENV_NAME"

#if ! (conda env list | grep "$ENV_NAME")
#then
#   echo "Conda environment specified is not found"
#   exit_function
#else
#   conda activate $ENV_NAME
#fi
#echo "packages before activating the environment"
#which python
#which pip

#echo "before activate environmment"
#conda info
#echo "activate conda environment $ENV_NAME"
#conda activate $ENV_NAME
#ls /home/projects/fvst_ssi_dtu/apps/sofi_bifrost_dev/conda/envs/
#ls /home/projects/fvst_ssi_dtu/apps/sofi_bifrost_dev/conda/envs/bifrost_dev_sp_cdiff_v0.0.1/
echo "Activating conda environment $ENV_NAME"

# Ensure conda is properly sourced
CONDA_BASE=$(conda info --base)
source $CONDA_BASE/etc/profile.d/conda.sh

# Check if the environment exists
if ! conda env list | grep -q "$ENV_NAME"; then
    echo "Conda environment $ENV_NAME does not exist. Please ensure it is created."
    exit 1
fi

CONDA_ENV_PATH=$(conda env list|awk '{print $2}' | grep -v '^$'|grep "$ENV_NAME")

conda activate $ENV_NAME

git clone $GIT_REPO
cd $REPO_FOLDER
echo "#################Installing package using pip"
PIP_PATH="$CONDA_ENV_PATH/bin/pip"
echo "installed pip path $INSTALLED_PIP_PATH"
$PIP_PATH install .
# Check where serum_readfilter is installed
INSTALLED_PATH=$(which serum_readfilter)

if [[ "$INSTALLED_PATH" == "~/.local/bin/serum_readfilter" ]]; then
  echo "Warning: serum_readfilter is installed in ~/.local/bin, which may cause conflicts."
  exit_function
fi

echo "serum_readfilter is installed at: $INSTALLED_PATH"
conda deactivate

cd $SCRIPT_DIR

# Initialize and update submodules
echo "################# Initializing and updating submodules..."
if ! git submodule update --init --recursive; then
  echo "Failed to initialize and update submodules."
  exit_function
fi

cd $SUBMODULE_PATH || { echo "Failed to enter submodule cdiff_fbi repository directory"; exit_function; }

# Fetch the latest tags
echo "################# Fetching the latest tags for the submodule..."
if ! git fetch origin --tags; then
  echo "Failed to fetch remote tags for the submodule."
  exit_function
fi

# Checkout the main branch
echo "################# Checking out main branch of submodule..."
if ! git checkout main; then
  echo "Failed to check out main branch."
  exit_function
fi

# Pull the latest changes from main
echo "################# Pulling the latest changes from main branch..."
if ! git pull origin main --tags; then
  echo "Failed to pull latest changes from main."
  exit_function
fi

# Determine the latest tag
LATEST_TAG=$(git rev-parse HEAD)
echo "Updated commit hash of $SUBMODULE_PATH after update: $LATEST_COMMIT"

# Identify the latest tag
LATEST_TAG_COMMIT=$(git for-each-ref --sort=-creatordate refs/tags | head -1 | cut -f1 -d ' ')
LATEST_TAG=$(git for-each-ref --sort=-creatordate refs/tags | head -1 | cut -f3 -d '/')

if [ -z "$LATEST_TAG_COMMIT" ] || [ -z "$LATEST_TAG" ]; then
  echo "No tags found in the submodule. Exiting."
  exit_function
fi

# Show the latest tag and its commit hash
echo "Checking commit hash for the latest tag of $SUBMODULE_PATH: $LATEST_TAG_COMMIT"
echo "Checking the latest tag of $SUBMODULE_PATH: $LATEST_TAG"

# Checkout the latest tag
echo "################# Checking out the latest tag..."
if ! git checkout "$LATEST_TAG_COMMIT"; then
  echo "Failed to check out the latest tag $LATEST_TAG_COMMIT."
  exit_function
fi

# Determine the latest tag
#LATEST_TAG=$(git rev-parse HEAD)
#echo "TAG $LATEST_TAG"

# Identify the latest tag
#LATEST_TAG_COMMIT=$(git for-each-ref --sort=-creatordate refs/tags | head -1 | cut -f1 -d ' ')
#LATEST_TAG=$(git for-each-ref --sort=-creatordate refs/tags | head -1 | cut -f3 -d '/')

#echo "TEST2 $LATEST_TAG: $LATEST_COMMIT"

cd $SCRIPT_DIR

echo "Installation complete"
