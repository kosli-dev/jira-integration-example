#!/usr/bin/env bash

# The following variable must be set before using this script
# export KOSLI_ORG=kosli-public
# export KOSLI_API_TOKEN="xx"

function loud_curl
{
  # curl that prints the server traceback if the response
  # status code is not in the range 200-299
  local -r method=$1; shift  # eg GET/POST
  local -r url=$1; shift
  local -r jsonPayload=$1; shift
  local -r userArg=$1;shift

  local -r outputFile=$(mktemp)

  set +e
  HTTP_CODE=$(curl --header 'Content-Type: application/json' \
       --user "${userArg}" \
       --output "${outputFile}" \
       --write-out "%{http_code}" \
       --request "${method}" \
       --silent \
       --data "${jsonPayload}" \
       ${url})
    set -e
    if [[ ${HTTP_CODE} -lt 200 || ${HTTP_CODE} -gt 299 ]] ; then
        >&2 cat ${outputFile}  # Request failed so send output to stderr
        >&2 echo
        rm ${outputFile}
        exit 2
    fi
    cat ${outputFile}  # Correct response send to stdout
    echo
    rm ${outputFile}
}

function loud_curl_kosli
{
    local -r userArg="${KOSLI_API_TOKEN}:unused"
    loud_curl "$@" ${userArg}
}


function get_current_running_env_json
{
    local -r envName=$1; shift
    kosli get snapshot ${envName} --output json | jq -r '[.artifacts[] | select(.annotation.now != 0)]'
}

function get_newest_commit_sha
{
    local -r envJson=$1; shift
    echo "$envJson" | jq -r '[.[] | .flows[]] | sort_by(.git_commit_info.timestamp) | .[-1].git_commit_info.sha1'
}

function get_oldest_commit_sha
{
    local -r envJson=$1; shift
    echo "$envJson" | jq -r '[.[] | .flows[]] | sort_by(.git_commit_info.timestamp) | .[0].git_commit_info.sha1'
}


function get_commits_between_staging_and_prod
{
    local -r stagingEnvName=$1; shift
    local -r prodEnvName=$1; shift

    stagingEnvJson=$(get_current_running_env_json ${stagingEnvName})
    prodEnvJson=$(get_current_running_env_json ${prodEnvName})
    newestCommit=$(get_newest_commit_sha "${stagingEnvJson}")
    oldestCommit=$(get_oldest_commit_sha "${prodEnvJson}")
    git log --format="%H" --reverse ${oldestCommit}..${newestCommit}
}

# We are missing Kosli CLI functionality for this, so we use curl and API
function get_jira_issue_keys_from_trail
{
    local -r flowName=$1; shift
    local -r trailName=$1; shift

    local -r url="https://app.kosli.com/api/v2/attestations/${KOSLI_ORG}/${flowName}/trail/${trailName}/jira-ticket"
    loud_curl_kosli GET "${url}" {} | jq -r '.[].jira_results[] | select(.issue_exists == true) | .issue_id'
}

function get_all_jira_issue_keys_for_commits
{
    local -r flowName=$1; shift
    local -r commits=$1; shift
    local issueKeys=""
    for commit in ${commits}; do
        issueKey=$(get_jira_issue_keys_from_trail $flowName $commit 2> /dev/null)
        issueKeys+=" $issueKey"
    done
    echo $issueKeys
}


function get_issue_keys_between_staging_and_prod
{
    local -r stagingEnvName=$1; shift
    local -r prodEnvName=$1; shift
    local -r flowName=$1; shift

    commits=$(get_commits_between_staging_and_prod ${stagingEnvName} ${prodEnvName})
    #echo "Commits between staging and prod: ${commits}" >&2
    issueKeys=$(get_all_jira_issue_keys_for_commits ${flowName} "${commits}")
    echo ${issueKeys} | tr ' ' '\n' | sort -u | tr '\n' ' '
}
