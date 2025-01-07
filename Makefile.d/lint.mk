#
# Linters Makefile
# This assumes a Posix system (MacOS, Linux or WSL2)
# Prior to performing a linter check, this tool will check
# to see if the linter is installed using 'command -v'
#
lint: lint/json lint/python lint/shell lint/yaml # Run all linters

lint/json: # Lint JSON
	@command -v jsonlint || {\
  		echo "jsonlint must be installed first.";\
  		exit 1; \
  	}
	@(\
		for f in $$(find ./ -name "*.json" -type f); do \
		  echo "linting $${f}"; \
		  jsonlint $${f} || exit 1; \
		done; \
	)

lint/python: # Lint Python
	@command -v flake8 || {\
 		echo "flake8 must be installed first."; \
 		exit 1; \
  	}
	@flake8  || exit 1

lint/shell: # Lint shell script
	@command -v shellcheck || {\
  		echo "shellcheck must be installed first.";\
  		exit 1; \
  	}
	@(\
		for f in $$(find ./ -name "*.sh" -type f); do \
		  echo "linting $${f}"; \
		  shellcheck $${f} || exit 1; \
		done; \
	)

lint/yaml: # Lint YAML
	@command -v yamllint || {\
  		echo "yamllint must be installed first.";\
  		exit 1; \
  	}
	@(\
		for f in $$(find ./ \( -name "*.yml" -o -name "*.yaml" \) -type f); do \
		  echo "linting $${f}"; \
		  yamllint $${f} || exit 1; \
		done; \
	)
