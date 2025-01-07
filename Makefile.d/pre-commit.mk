
pc_install: # Install pre-commit plugins
	pre-commit install

pc_run: # Run pre-commit hooks on all files
	pre-commit run --all-files --show-diff-on-failure
