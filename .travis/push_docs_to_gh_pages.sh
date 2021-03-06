#!/bin/bash

# Many aspects of this came from https://gist.github.com/domenic/ec8b0fc8ab45f39403dd
# Significant alterations
# - Support for multiple copies of documentation,
#   - only clearing out develop
#   - index.md logging doc history

# How to run:
#  - From repository root .travis/push_docs_to_gh_pages.sh

# Required files / directories (relative from repo root)
# - File: "docs/index.md" with that contains develop docs

# Required ENV Variables
PAGES_TARGET_BRANCH="gh-pages"
LATEST_DOCS_BRANCH="develop"
#  TRAVIS_* variables are set by travis directly and only need to be if testing externally

# We don't want a pull request automatically updating the repository
if [ "$TRAVIS_PULL_REQUEST" == "false" ] && { [ "${CURRENT_BRANCH}" == "${LATEST_DOCS_BRANCH}" ] || [ -n "${TRAVIS_TAG}" ]; }; then

  # ENV Variable checks are to help with configuration troubleshooting, they silently exit with unique message.
  # Anyone one of them not set can be used to turn off this functionality.

  # If a version of the project is not defined
  [[ -n "${UTPLSQL_VERSION}" ]] || { echo "variable UTPLSQL_VERSION is not defines or missing value";  exit 0; }
  # Fail if the markdown documentation is not present.
  [[ -f ./docs/index.md ]] || { echo "file docs/index.md not found";  exit 1; }

  # Save some useful information
  SHA=`git rev-parse --verify HEAD`

  # clone the repository and switch to PAGES_TARGET_BRANCH branch
  mkdir pages
  cd pages
  git clone https://${github_api_token}@github.com/${UTPLSQL_REPO} .

  PAGES_BRANCH_EXISTS=$(git ls-remote --heads origin ${PAGES_TARGET_BRANCH})

  if [ -n "$PAGES_BRANCH_EXISTS" ] ; then
    echo "Pages Branch Found"
    git checkout ${PAGES_TARGET_BRANCH}
  else
    echo "Creating Pages Branch"
    git checkout --orphan ${PAGES_TARGET_BRANCH}
    git rm -rf .
  fi
  #clear out develop documentation directory and copy docs contents to it.
  echo "updating 'develop' directory"
  mkdir -p develop
  rm -rf develop/**./* || exit 0
  cp -a ../docs/. ./develop
  # If a Tagged Build then copy to it's own directory as well and to the 'latest' release directory
  if [ -n "$TRAVIS_TAG" ]; then
   echo "Creating ${UTPLSQL_VERSION}"
   mkdir -p ${UTPLSQL_VERSION}
   rm -rf ${UTPLSQL_VERSION}/**./* || exit 0
   cp -a ../docs/. ${UTPLSQL_VERSION}
   echo "Populating 'latest' directory"
   mkdir -p latest
   rm -rf latest/**./* || exit 0
   cp -a ../docs/. latest
  fi
  # Stage changes for commit
  git add .
  #Check if there are doc changes, if none exit the script
  if [[ -z `git diff HEAD --exit-code` ]] && [ -n "${PAGES_BRANCH_EXISTS}" ] ; then
    echo "No changes to docs detected."
    exit 0
  fi
  #Changes where detected, so we need to update the version log.
  now=$(date +"%d %b %Y - %r")
  if [ ! -f index.md ]; then
    echo "---" >>index.md
    echo "layout: default" >>index.md
    echo "---" >>index.md
    echo "<!-- Auto generated from .travis/push_docs_to_gh_pages.sh -->" >>index.md
    echo "# Documentation versions" >>index.md
    echo "" >>index.md
    echo "" >>index.md #- 7th line - placeholder for latest release doc
    echo "" >>index.md #- 8th line - placeholder for develop branch doc
    echo "" >>index.md
    echo "## Released Version Doc History" >>index.md
    echo "" >>index.md
  fi
  #If build running on a TAG - it's a new release - need to add it to documentation
  if [ -n "${TRAVIS_TAG}" ]; then
    sed -i '7s@.*@'" - [Latest ${TRAVIS_TAG} documentation](latest/) - Created $now"'@' index.md
    #add entry to the top of version history (line end of file - ## Released Version Doc History
    sed -i '12i'" - [${TRAVIS_TAG} documentation](${UTPLSQL_VERSION}/) - Created $now" index.md
  fi
  #replace 4th line in log
  sed -i '8s@.*@'" - [Latest development version](develop/) - Created $now"'@'  index.md
  #Add and Commit the changes back to pages repo.
  git add .
  git commit -m "Deploy to gh-pages branch: base commit ${SHA}"
  # Now that we're all set up, we can push.
  git push --quiet origin HEAD:${PAGES_TARGET_BRANCH}
fi

