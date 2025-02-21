SHELL  := bash

deploy_to_staging:
	@git remote update
	@git status --untracked-files=no | grep --silent "Your branch is up to date" || (echo "ERROR: your branch is NOT up to date with remote" && exit 1)
	git tag staging-${TIMESTAMP}
	git push origin staging-${TIMESTAMP} $(args)

	# The rest is a little extra for simulating the staging environment.
	@if git rev-parse staging-running >/dev/null 2>&1; then \
		git tag -d staging-running; \
		git push --delete origin staging-running; \
	fi
	git tag staging-running
	git push origin staging-running
