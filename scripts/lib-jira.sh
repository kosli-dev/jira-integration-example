#!/usr/bin/env bash

#JIRA_BASE_API="https://kosli-team.atlassian.net"
#JIRA_USERNAME="tore@kosli.com"
#JIRA_API_TOKEN="xx"
#JIRA_PROJECT_ID=10000
#JIRA_APPROVER_ID="11111111111"

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

function loud_curl_jira
{
    local -r userArg=""${JIRA_USERNAME}:${JIRA_API_TOKEN}""
    loud_curl "$@" ${userArg}
}

function create_release
{
    local -r projectId=$1; shift
    local -r releaseName=$1; shift

    local -r url="${JIRA_BASE_API}/rest/api/3/version"
    local -r data='{
         "description": "An excellent version",
         "name": "'${releaseName}'",
         "projectId": '${projectId}',
         "approvers": [{
             "accountId": "'${approverId}'"
         }]
    }'
    loud_curl_jira POST "${url}" "${data}"
}

function get_current_release_candidate
{
    local -r projectId=$1; shift

    local -r url="${JIRA_BASE_API}/rest/api/3/project/${projectId}/version?status=unreleased"
    loud_curl_jira GET "${url}" {}
}

function get_release
{
    local -r releaseId=$1; shift

    local -r url="${JIRA_BASE_API}/rest/api/3/version/${releaseId}?expand=approvers"
    loud_curl_jira GET "${url}" {}
}


function add_approver_to_release
{
    # Might be a problem https://community.developer.atlassian.com/t/add-approver-to-version-through-rest-api/76975
    local -r approverId=$1; shift
    local -r releaseId=$1; shift

    local -r url="${JIRA_BASE_API}/rest/api/3/version/${releaseId}"
    local -r data='{
        "approvers": [{
            "accountId": "'${approverId}'"
        }]
    }'
    loud_curl_jira PUT "${url}" "${data}"
}

function add_issue_to_release() {
    local -r issueKey=$1; shift
    local -r releaseId=$1; shift

    local -r url="${JIRA_BASE_API}/rest/api/3/issue/${issueKey}"
    local -r data='{
        "fields": {
            "fixVersions": [{
                "id": "'${releaseId}'"
            }]
        }
    }'
    loud_curl_jira PUT "${url}" "${data}"
}

function get_issue {
    local -r issueKey=$1; shift

    local -r url="${JIRA_BASE_API}/rest/api/3/issue/${issueKey}"
    loud_curl_jira GET "${url}" {}
}

#RELEASE_NAME=2025.02.20-r1
#get_current_release_candidate ${JIRA_PROJECT_ID}
#create_release ${JIRA_PROJECT_ID} ${RELEASE_NAME}
#get_release 10033
#get_issue OPS-5
#add_issue_to_release OPS-5 10033
#add_approver_to_release ${JIRA_APPROVER_ID} 10033
