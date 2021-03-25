#!/bin/sh -l

# show colors
export TERM=xterm-color

# if a command fails it stops the execution
set -e

# script fails if trying to access to an undefined variable
set -u

YELLOW='\033[0;33m'
NO_COLOR='\033[0m'

function note()
{
    MESSAGE=$1;

    printf "\n${YELLOW}";
    echo "[NOTE] $MESSAGE";
    printf "\n${NO_COLOR}";
}

note "Starts"

PACKAGE_DIRECTORY="$1"
SPLIT_REPOSITORY_ORGANIZATION="$2"
SPLIT_REPOSITORY_NAME="$3"
COMMIT_MESSAGE="$4"
BRANCH="$5"
TAG="$6"
USER_EMAIL="$7"
USER_NAME="$8"
SPLIT_REPOSITORY_HOST="$9"


# @todo also for split from gitlab
COMMIT_SHA=$GITHUB_SHA


# setup access token so went push repository
if test -n "${GITHUB_TOKEN-}"
then
    PAT=$GITHUB_TOKEN
    HOST_PREFIX=
fi

if test -n "${GITLAB_TOKEN-}"
then
    PAT=$GITLAB_TOKEN
    HOST_PREFIX="oauth2:"
fi


# setup git
if test ! -z "$USER_EMAIL"
then
    git config --global user.email "$USER_EMAIL"
fi

if test ! -z "$USER_NAME"
then
    git config --global user.name "$USER_NAME"
fi

CLONE_DIR='clone_directory'
TARGET_DIR='build_directory'

HOST_REPOSITORY_ORGANIZATIN_NAME=$SPLIT_REPOSITORY_HOST/$SPLIT_REPOSITORY_ORGANIZATION/$SPLIT_REPOSITORY_NAME.git

CLONED_REPOSITORY="https://$HOST_REPOSITORY_ORGANIZATIN_NAME"
note "Cloning '$CLONED_REPOSITORY' repository "

# clone repository
git clone -- "https://$HOST_PREFIX$PAT@$HOST_REPOSITORY_ORGANIZATIN_NAME" "$CLONE_DIR"
ls -la "$CLONE_DIR"

note "Cleaning destination repository of old files"

# We're only interested in the .git directory, move it to $TARGET_DIR and use it from now on.
cp "$CLONE_DIR/.git" "$TARGET_DIR/.git"

ls -la "$TARGET_DIR"


FULL_GITHUB_REPOSITORY="https://github.com/$GITHUB_REPOSITORY"

if test ! -z "$COMMIT_MESSAGE"
then
    ORIGIN_COMMIT="$FULL_GITHUB_REPOSITORY/commit/$COMMIT_SHA"
    COMMIT_MESSAGE="${COMMIT_MESSAGE/ORIGIN_COMMIT/$ORIGIN_COMMIT}"
else
    COMMIT_MESSAGE=$(git show -s --format=%B "$COMMIT_SHA")
fi


note "Copying contents to git repo of '$BRANCH' branch"

# copy the package directory including all hidden files to the clone dir
# make sure the source dir ends with `/.` so that all contents are copied (including .github etc)
cp -Ra $PACKAGE_DIRECTORY/. "$TARGET_DIR"

note "Files that will be pushed"


ls -la

cd "$TARGET_DIR"
ls -la


php ../src/commit_if_changed_files.php


# push tag if present
if test ! -z "$TAG"
then
    note "Publishing tag: ${TAG}"

    # if tag already exists in remote
    TAG_EXISTS_IN_REMOTE=$(git ls-remote origin refs/tags/$TAG)

    # tag does not exist
    if test -z "$TAG_EXISTS_IN_REMOTE"
    then
        git tag $TAG -m "Publishing tag ${TAG}"
        git push --quiet origin "${TAG}"
    fi
fi
