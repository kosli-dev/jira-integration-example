#!/usr/bin/env bash

export KOSLI_ORG=kosli-public
export KOSLI_API_TOKEN=xx
KOSLI_ENV_STAGING=jira-integration-example-staging
KOSLI_ENV_PROD=jira-integration-example-prod
KOSLI_FLOW_FRONTEND=jira-example-frontend
KOSLI_FLOW_BACKEND=jira-example-backend

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
    kosli get snapshot ${envName} --output json | jq  '[.artifacts[] | select(.annotation.now != 0)]'
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

function get_jira_issue_keys_from_trail
{
    local -r flowName=$1; shift
    local -r trailName=$1; shift

    local -r url="https://app.kosli.com/api/v2/attestations/${KOSLI_ORG}/${flowName}/trail/${trailName}/jira-ticket"
    loud_curl_kosli GET "${url}" {} | jq -r '.[].jira_results[].issue_id'
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

COMMITS=$(get_commits_between_staging_and_prod ${KOSLI_ENV_STAGING} ${KOSLI_ENV_PROD})
ISSUE_KEYS=""
KEYS=$(get_all_jira_issue_keys_for_commits ${KOSLI_FLOW_FRONTEND} "${COMMITS}")
ISSUE_KEYS+=" $KEYS"
KEYS=$(get_all_jira_issue_keys_for_commits ${KOSLI_FLOW_BACKEND} "${COMMITS}")
ISSUE_KEYS+=" $KEYS"
ISSUE_KEYS=$(echo $ISSUE_KEYS | tr ' ' '\n' | sort -u)

echo $ISSUE_KEYS
#get_jira_issue_keys_from_trail jira-example-frontend eea3dcd96d366768bb88c5dcf079cfdec2557bcc

#a=$(get_current_env_json ${KOSLI_ENV_STAGING})
#get_newest_commit_sha "${a}"
#
#a=$(get_current_env_json ${KOSLI_ENV_PROD})
#get_oldest_commit_sha "${a}"
