# Start by just using the "nearest" python3 ...
PYTHON ?= python3
# Don't use pyenv?
ifeq ("$(PYENV_VIRTUAL_ENV)","")
# No virtual env? (yet)
ifeq ("$(VIRTUAL_ENV)","")
ifneq ("$(wildcard /opt/homebrew/bin/python3)","")
	PYTHON ?= /opt/homebrew/bin/python3
endif
endif
endif

ifndef PYTHON_MK_INCLUDED
python_init: # Init Python venv and install pip requirements
	@if test ! -f $(ROOT_DIR)/.python-version ; then \
		$(PYTHON) -m venv .venv ; \
		. .venv/bin/activate ; \
	fi
	@if [[ "yes" != "$$INIT_WITH_POETRY" ]]; then \
		$(SNAKE); \
		[[ ! -f requirements.txt ]] || $(PYTHON) -m pip install -r requirements.txt ; \
		[[ ! -f $(ROOT_DIR)/requirements.txt ]] || $(PYTHON) -m pip install -r $(ROOT_DIR)/requirements.txt ; \
	fi

python_venv: python_init # Init Python venv and install pip requirements
	@[ ! poetry version 2>/dev/null ] || { cd $(ROOT_DIR); poetry install --with dev; }

PYTHON_MK_INCLUDED := yes
endif
