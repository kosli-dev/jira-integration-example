SHELL  := bash

deploy_to_staging:
	gh workflow run deploy-to-staging.yml --ref main

generate_jira_release:
	gh workflow run generate-jira-release.yml --ref main

check_release_to_prod:
	gh workflow run release-to-prod.yml --ref main

make update_tags:
	git fetch --tags --force

report_all_envs:
	gh workflow run simulate-environment-reporting-dev.yml --ref main
	gh workflow run simulate-environment-reporting-staging.yml --ref main
	gh workflow run simulate-environment-reporting-prod.yml --ref main
