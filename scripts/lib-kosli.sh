#!/usr/bin/env bash

#export KOSLI_ORG=kosli-public
#export KOSLI_API_TOKEN="xx"
#KOSLI_ENV_STAGING=jira-integration-example-staging
#KOSLI_ENV_PROD=jira-integration-example-prod
#KOSLI_FLOW_FRONTEND=jira-example-frontend
#KOSLI_FLOW_BACKEND=jira-example-backend

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
    set -o pipefail
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

function get_artifact_flow_commit_mapping_json
{
    # Will return something similar to this
    #[
    #  {
    #    "name": "frontend",
    #    "flow_name": "jira-example-frontend",
    #    "staging_git_commit": "bcfd4b6439af92012dd6fdabd2a53f297759cc52",
    #    "prod_git_commit": "45254f18599330c0e08fe59fcf8bc818972e220f"
    #  },
    #  {
    #    "name": "backend",
    #    "flow_name": "jira-example-backend",
    #    "staging_git_commit": "bcfd4b6439af92012dd6fdabd2a53f297759cc52",
    #    "prod_git_commit": "45254f18599330c0e08fe59fcf8bc818972e220f"
    #  }
    #]

    local -r stagingEnvName=$1; shift
    local -r prodEnvName=$1; shift

    stagingEnvJson=$(get_current_running_env_json ${stagingEnvName})
    prodEnvJson=$(get_current_running_env_json ${prodEnvName})
    echo "${stagingEnvJson}" | jq -r '
      [
        .[] |
        {
          name: .name,
          flow_name: .flow_name,
          staging_git_commit: .git_commit
        }
      ]' | jq --argjson prodEnvJson "${prodEnvJson}" '
      [
        .[] |
        . + (
          ($prodEnvJson | map(select(.name == .name and .flow_name == .flow_name)) | .[0]) |
          {prod_git_commit: .git_commit}
        )
      ]'
}

function get_issue_keys_between_staging_and_prod
{
    commits=$(get_commits_between_staging_and_prod ${KOSLI_ENV_STAGING} ${KOSLI_ENV_PROD})
    echo "Commits between staging and prod: ${commits}" >&2
    issueKeys=""
    keys=$(get_all_jira_issue_keys_for_commits ${KOSLI_FLOW_FRONTEND} "${commits}")
    issueKeys+=" ${keys}"
    keys=$(get_all_jira_issue_keys_for_commits ${KOSLI_FLOW_BACKEND} "${commits}")
    issueKeys+=" ${keys}"
    echo ${issueKeys} | tr ' ' '\n' | sort -u | tr '\n' ' '
}

#get_issue_keys_between_staging_and_prod

#artifactFlowMapping=$(get_artifact_flow_commit_mapping_json ${KOSLI_ENV_STAGING} ${KOSLI_ENV_PROD})
#
#echo "$artifactFlowMapping" | jq -c '.[]' | while read -r artifact; do
#    prod_git_commit=$(echo "$artifact" | jq -r '.prod_git_commit')
#    staging_git_commit=$(echo "$artifact" | jq -r '.staging_git_commit')
#
#    git log --format="%H" "$prod_git_commit..$staging_git_commit"
#done


#exit 0
#
#names=""
#declare -A flow_names
#declare -A staging_git_commits
#declare -A prod_git_commits
#
#while IFS= read -r line; do
#    name=$(echo "$line" | awk '{print $1}')
#    flow_names["$name"]=$(echo "$line" | awk '{print $2}')
#    staging_git_commits["$name"]=$(echo "$line" | awk '{print $3}')
#    names+=" $name"
#done <<< "$(echo "${stagingEnvJson}" | jq -r '.[] | "\(.name) \(.flow_name) \(.git_commit)"')"
#
#while IFS= read -r line; do
#    name=$(echo "$line" | awk '{print $1}')
#    prod_git_commits["$name"]=$(echo "$line" | awk '{print $3}')
#    names+=" $name"
#done <<< "$(echo "${prodEnvJson}" | jq -r '.[] | "\(.name) \(.flow_name) \(.git_commit)"')"
#
#
#for name in ${names}; do
#  echo "Name: $name"
#  echo "Flow Name: ${flow_names[$name]}"
#  echo "Stag Commit: ${staging_git_commits[$name]}"
#  echo "Prod Commit: ${prod_git_commits[$name]}"
#  echo "-----"
#  git log --format="%H" --reverse ${prod_git_commits[$name]}..${staging_git_commits[$name]}
#done


#get_jira_issue_keys_from_trail jira-example-frontend eea3dcd96d366768bb88c5dcf079cfdec2557bcc

#a=$(get_current_env_json ${KOSLI_ENV_STAGING})
#get_newest_commit_sha "${a}"
#
#a=$(get_current_env_json ${KOSLI_ENV_PROD})
#get_oldest_commit_sha "${a}"
