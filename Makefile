SHELL  := bash

TIMESTAMP := $(shell date -u "+%Y-%m-%d-%H-%M-%S")

deploy_to_staging:
	@git remote update
	@git status --untracked-files=no | grep --silent "Your branch is up to date" || (echo "ERROR: your branch is NOT up to date with remote" && exit 1)
	git tag staging-${TIMESTAMP}
	git push origin staging-${TIMESTAMP} $(args)

make update_tags:
	git fetch --tags --force

create_release_candidate:
	gh workflow run create-release.yml --ref main
