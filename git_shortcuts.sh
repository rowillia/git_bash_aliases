# Slack Config
export SLACK_TOKEN=$(>&2 echo "Get a slack token from https://api.slack.com/web and set it here.")
export DEFAULT_SLACK_PR_ROOM=$(>&2 echo "Set DEFAULT_SLACK_PR_ROOM to specify which room messages should go to by default.")

# Github config

if ! which hub > /dev/null; then
  >&2 "Download the github CLI from https://github.com/github/hub"
  exit 1
fi

if ! which slackcli > /dev/null; then
  >&2 "Optionally install the slackcli from https://www.npmjs.com/package/slack-cli"
fi

alias git=hub
# Function to create a pull request and ping a slack channel with the URL
function cpr() {
  (
    set -e
    while getopts "m:c:g:" OPTION; do
      case $OPTION in
        m)
          message="${OPTARG}"
          ;;
        g)
          group_flag="-g"
          group="${OPTARG}"
          ;;
        c)
          group_flag="-h"
          group="${OPTARG}"
          ;;
      esac
    done
    local commit_suffix=
    if [ -n "${message}" ]; then
      commit_suffix="-m '${message}'"
    else
      commit_suffix="--amend --no-edit"
    fi
    if ! git diff --exit-code > /dev/null; then
      sh -c "git commit -a $commit_suffix"
    fi
    local message="${message-$(git log -1 --pretty=%B)}"
    local group="${group-$DEFAULT_SLACK_PR_ROOM}"
    git push origin "$(git rev-parse --abbrev-ref HEAD)" -f
    local pr_url
    pr_url="$(git pull-request -m "$message")"
    echo "Pull Requset URL: ${pr_url}"
    if [ -n "${pr_url}" ] && \
       which slackcli &> /dev/null && \
       [ -n "${SLACK_TOKEN}" ]; then
      slackcli -u "$USERNAME" \
        -e ":robotface:" \
        ${group_flag} "${group}" \
        -m "<!here|here> $pr_url ($message)"
    fi
  )
}

function feature() {
  (
    set -e
    local feature_name=$1
    local stash_output
    stash_output="$(git stash)"
    git checkout master
    git pull --rebase origin master
    git checkout -b "$feature_name"
    if [[ $stash_output != "No local changes to save" ]]; then
      git stash apply
    fi
  )
}

function rename-branch() {
  (
    local from=$1
    local to=$2
    git checkout "$from"
    git pull --rebase origin master
    git branch -m "$to"
    git push origin :"$from" &> /dev/null
  )
}

# Updates a pull request
alias upr='git push origin $(git rev-parse --abbrev-ref HEAD) -f'

# Amends the current commit and updates the pull request.
alias apr='git commit -a --amend --no-edit && upr'

# Delete any branches that aren't tracked remotely.
function clean-up-branches() {
  set -e
  local force_delete='false'
  while getopts "f" OPTION; do
    case $OPTION in
      f)
        force_delete='true'
        ;;
    esac
  done
  local remote_branches
  remote_branches="$(git ls-remote &> /dev/null | \
                     grep 'refs/heads' | \
                     cut -d'/' -f3 | sort)"
  local local_branches
  local_branches="$(git branch | grep -v '\*' | sed 's/ //g' | sort)"
  local branches_to_delete
  branches_to_delete="$(comm -23 \
                        <(echo "$local_branches") \
                        <(echo "$remote_branches"))"
  if $force_delete; then
    echo "$branches_to_delete" | xargs git branch -D
    git gc
  else
    echo "The following branches aren't tracked remotely and will be deleted:"
    echo "$branches_to_delete"
  fi
}
