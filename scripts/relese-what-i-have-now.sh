#!/usr/bin/env bash
set -Eeu

SCRIPT_NAME=release-what-i-have-now.sh
ROOT_DIR=$(dirname $(readlink -f $0))/..

function print_help
{
    cat <<EOF
Usage: $SCRIPT_NAME <options>

Script that will deploy current sw to staging, create a release candidate
and then deploy it to staging when approved.

Options are:
  -h          Print this help menu
EOF
}

function check_arguments
{
    while getopts "h" opt; do
        case $opt in
            h)
                print_help
                exit 1
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done
}

function wait_for_github_actions
{
    sleep 10
    echo -n "Waiting for GitHub Actions to complete "

    while true; do
        result=$(gh run list --json status)
        # Check if there are any workflows that are not completed
        if echo "$result" | jq -e '.[] | select(.status != "completed")' > /dev/null; then
            echo -n "."
            sleep 2
        else
            break
        fi
    done
    echo
}


main()
{
    check_arguments "$@"
    echo "*** Report all running environments"
    make report_all_envs > /dev/null; wait_for_github_actions
    echo; echo "*** SW is now running in dev. Do a deployment from dev to staging"
    make deploy_to_staging; wait_for_github_actions
    make report_all_envs > /dev/null; wait_for_github_actions
    echo; echo "*** Make a release candidate for SW now running in staging"
    make generate_jira_release; wait_for_github_actions

    echo; echo "*** Go to url:"
    echo "https://kosli-team.atlassian.net/projects/OPS?selectedItem=com.atlassian.jira.jira-projects-plugin%3Arelease-page"
    echo
    echo "Press the version you see in the list. It should only be one that is UNRELEASED"
    echo "On the right hand side press the + next to Approvers"
    echo "Add your self as an approver"
    echo "Change the approval from PENDING to APPROVED"
    echo "After that press 'c' to continue"
    while :; do
      read -n 1 key
      if [[ "$key" == "c" ]]; then
        echo -e "\nContinuing..."
        break
      fi
    done
    echo; echo "*** Check if release has been approved"
    make check_release_to_prod; wait_for_github_actions
    make report_all_envs > /dev/null; wait_for_github_actions
    make update_tags
    echo; echo "*** You can now check kosli UX to see that correct SW is running and that attestations have been done"
}

main "$@"
