SHELL  := bash

deploy_to_staging:
	gh workflow run deploy-to-staging.yml --ref main

make update_tags:
	git fetch --tags --force

create_release_candidate:
	gh workflow run create-release.yml --ref main
