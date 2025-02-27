# jira-integration-example
An example on how Kosli can integrate with Jira and GitHub in a
complete release process.


# Simulated project

The project has two applications `frontend` and `backend`. The
two applications are in the same git repository, but are 
updated and released independently.

The "source code" for the two applications are the two files
```
apps/backend/backend-content.txt
apps/frontend/frontend-content.txt
```
To simulate a change of the software in an application just
increase the `counter=xx` number in the file.

There is a CI-pipeline build step for the 
[backend](https://github.com/kosli-dev/jira-integration-example/actions/workflows/build-backend.yml)
and one for the
[frontend](https://github.com/kosli-dev/jira-integration-example/actions/workflows/build-frontend.yml).
The CI-pipeline are only triggerd on changes to that particular application.

There are no real servers in this demo. We use some git tags to indicate what software is
running on which server:
- running-staging-backend
- running-staging-frontend
- running-prod-backend
- running-prod-frontend
For development we use the latest version checked in on `main`

There are three GitHub actions that simulate the reporting of snapshots. 
- Report development snapshot
- Report staging snapshot
- Report prod snapshot
They trigger automatically once an hour, but can also be triggered manually.


# Software Process

The software process works like this:
- All commits to `main` must have to have a `pull-request` and a `jira-issue` reference.
- Applications in repo are released independently.
- Any developer can promote the current dev-server software to the staging-server.
- A developer decides when he/she thinks the current staging-server software is ready
for release and creates a **release candidate**
- The **release candidate** shall be visible in Jira with a list of Jira-issues that are
included in the release.
- The product owner shall review the **release candidate** in Jira and test it on staging-server.
- Any issues found in a **release candidate** must be mitigated before deployment to production-server.
- The product owner is free to make new Jira-issues or just talk with developers.
- Developer fixes the issue, deploy the fix to staging and then updates the **release candidate**
with any ny Jira-issues.
- When satisfied with the **release candidate** the product owner approves it in Jira.
- When a **release candidate** is approved by all approvers it will automatically be
deployed to production-server.
- There can only be one open **release candidate** at a time.


# Reporting to Kosli

The software delivery process is documented in Kosli. 

For the source control and build of software we use the following flows:
- `jira-example-source` - document that all pushes to main has pull-request and Jira-issue reference
- `jira-example-frontend` - document the build of frontend artifact and also the pull-request and Jira-issue reference
- `jira-example-backend` - document the build of backend artifact and also the pull-request and Jira-issue reference
All flows uses the git-commit as the trail name.

For the servers we use the following **server** environments:
- `jira-integration-example-dev` - document what is running on development server
- `jira-integration-example-staging` - document what is running on staging server
- `jira-integration-example-prod` - document what is running on production server


# Release process

Merges to `main` that updates any of the applications trigger a build and automatic deployment
to dev-server of that applications.

## Promote to staging
The developers are free to decide when they want to promote what is running on dev-server to staging-server.
The developers can trigger the **Deploy to Staging** GitHub action by running
```
make deploy_to_staging
```
This job does the following:
- Use Kosli to find out what software that is currently running on development. 
This includes the fingerprint of the artifact and the commit it was built from. 
In this simulated setup we use the commit to find the correct version  to deploy 
to staging for each artifact.
- In a normal setup the applications that had to be updated would be deployed, 
but in this simulated setup we only update some git tags.

## Release to production
When a developer thinks that what is currently running in staging should be released
to production they  create a **release candidate**. The developers can trigger the
**Create release candidate** GitHub action by running:
```
make create_release_candidate
```
This job does the following:
- Use Kosli to find out what software that is currently running on staging and
production.
- Use Kosli to find all Jira-issues that has been referenced in git commits
since last deployment to production
- Creat a Jira-release. Use date-time as name of release for now.
- Add all Jira-issues to the Jira-release

The Jira API does not support adding an approver to a release, so the product owner
has to manually add them self as an approver in the UX. It is possible to add
multiple approvers.

If the product owner finds a problem with the release they inform the
developers.

After the developers has added a fix and deployed it to staging they update the
**release candidate**. The developers can trigger the
**Update release candidate** GitHub action by running:
```
make update_release_candidate
```

When all approvers have set the approval to `APPROVED` the software can be deployed
to production.

There is a **Release to Prod** GitHub action that runs every hour. It can also be
triggered manually by running:
```
make check_release_to_prod
```
This job does the following:
- Gets the current release candidate from Jira
- Check that there is at least one approver
- Checks that all approvers has set the state to `APPROVED`
- Attest to Kosli that the release candidate was approved
- Deploy software to prod-server. In this simulated environment we just move
the 'running-prod-xxx' tags.
- Set the Jira release to **Released**


# Demo of complete process
It is possible to run a demo of the complete process.
Go to the [jira board](https://kosli-team.atlassian.net/jira/software/projects/OPS/boards/1)
and add two new Jira-issues. The Jira-issues have issue-key like OPS-11 and OPS-12
Go to the [release page](https://kosli-team.atlassian.net/projects/OPS?selectedItem=com.atlassian.jira.jira-projects-plugin%3Arelease-page)
and make sure there are no **Unreleased** versions. If there is you have to archive them.

Run the following script with the two IDs you created (currently only tested on Linux)
```
./scripts/demo-jira-release.sh OPS-11 OPS-12
```
The script takes approximately 10 minutes to run, and requires some interaction
after approximately 8 minutes.

You should be able to see the flows and environments in Kosli and also see that
the release is updated in Jira.

We currently also have a `jira-example-release` flow, but this needs some improvement.

https://app.kosli.com/kosli-public/flows/
https://app.kosli.com/kosli-public/environments/


# Things to improve

Make the scripts a little more streamlined and make it easy to just give
a list of apps/environments and loop over them.

There is no CLI command to get the Jira-issues from Kosli, so I have to use curl.

I report the Jira issue and pull request on both the source and build flows. A link
from the source trail to build trail would be nice. But for proper linking we
need to let a trail event on one trail trigger also a trail event on the other trails that it
links to.

A release is very important for the customer I think we should have that
consept in Kosli. What do we need?
- In this case we only want things in prod that has been released. Provenance 
from a build to staging is not compliant.
- A release consists of a set of versions of applications. We should record
that combination.
- Do we want to validate that the combination of software in a release is
also the combination running in production?
- Record who approved a release
- Record the list of Jira issues included in release (also state if they want)
- I do a lot of API calls to get the list of commits in a release, and then
I loop over all the commits to collect all the Jira issues included. This
gives me some complicated bash scripts, which is hard to maintain.
