#!/bin/bash
#Script executes these commands with safeguards in place:
# - Clones the main repository.
# - Installs the main repository package.
# - Updates the `cdiff_fbi` submodule to the latest tag.

GIT_REPO=https://github.com/ssi-dk/serum_readfilter
REPO_FOLDER=serum_readfilter
SUBMODULE_PATH="bifrost_sp_cdiff/cdiff_fbi"  # Path to the submodule

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR || exit 1  # Avoid small edge case where bashrc sourcing changes your directory

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

# Check for git availability
if ! command -v git &>/dev/null; then
  echo "git is not installed."
  echo "You can try installing git and rerunning the script."
  exit_function
fi

# Clone the main repository if it does not exist
if test -d "$SCRIPT_DIR/$REPO_FOLDER"; then
  echo "$SCRIPT_DIR/$REPO_FOLDER already exists. If you want to overwrite, please remove the old repository folder:"
  echo "rm -rf $SCRIPT_DIR/$REPO_FOLDER"
  exit_function
else
  echo "################# Cloning repository from $GIT_REPO"
  if ! git clone $GIT_REPO; then
    echo >&2 "git clone command failed."
    exit_function
  fi
fi

# Navigate into the main repository
cd $REPO_FOLDER || { echo "Failed to enter repository directory"; exit_function; }

# Initialize and update submodules
echo "################# Initializing and updating submodules..."
if ! git submodule update --init --recursive; then
  echo "Failed to initialize and update submodules."
  exit_function
fi

# Navigate to the submodule directory
if ! test -d "$SUBMODULE_PATH"; then
  echo "Submodule path $SUBMODULE_PATH does not exist. Exiting."
  exit_function
fi

cd $SUBMODULE_PATH || { echo "Failed to enter submodule directory $SUBMODULE_PATH"; exit_function; }

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

# Navigate back to the main repository directory
cd "$SCRIPT_DIR/$REPO_FOLDER" || exit_function

# Install the main package using pip
echo "################# Installing package using pip..."
if ! pip install .; then
  echo >&2 "pip install command failed."
  exit_function
else
  echo "Package successfully installed."
fi

echo "################# Installation complete."
