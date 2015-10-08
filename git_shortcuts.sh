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

# Function to create a pull request and ping a slack channel with the URL
function cpr() {
  (
    set -e
    set -x
    while getopts “m:c:” OPTION; do
      case $OPTION in
        m)
          message="${OPTARG}"
          ;;
        c)
          group="${OPTARG}"
          ;;
      esac
    done
    if [ -n "${message}" ]; then
      if ! git diff --exit-code > /dev/null; then
        git commit -a -m "${message}"
      fi
    fi
    local message="${message-$(git log -1 --pretty=%B)}"
    local group="${group-$DEFAULT_SLACK_PR_ROOM}"
    git push origin $(git rev-parse --abbrev-ref HEAD) -f
    local pr_url=$(git pull-request -m "$message")
    echo "Pull Requset URL: ${pr_url}"
    if which slackcli &> /dev/null && [ -n "${SLACK_TOKEN}" ]; then
      slackcli -u "review_bot" -e ":robotface:" -g "${group}" -m "<!here|here> $USERNAME needs a code review - $pr_url ($message)"
    fi
  )
}

# Creates a feature branch
function feature() {
  (
    set -e
    local feature_name=$1
    git checkout master
    git pull --rebase origin master
    git checkout -b $feature_name
  )
}

# Updates a pull request
alias upr='git push origin $(git rev-parse --abbrev-ref HEAD) -f'

# Amends the current commit and updates the pull request.
alias apr='git commit -a --amend --no-edit && upr'
