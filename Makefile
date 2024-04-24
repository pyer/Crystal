# Recipes for this Makefile

## Build the compiler
##   $ make
## Build the compiler with progress output
##   $ make progress=1
## Build the compiler in release mode
##   $ make release=1
## Build the compiler with crystal
##   $ make crystal
## Clean up built files
##   $ make clean
## Test the compiler
##   $ make test

SHELL := /bin/bash

# llvm-config command path to use
LLVM_VERSION  := $(shell llvm-config --version)
LLVM_CXXFLAGS := $(shell llvm-config --cxxflags)
LLVM_EXT_SRC  := /usr/share/crystal/src/llvm/ext/llvm_ext.cc
LLVM_EXT_OBJ  := /usr/share/crystal/src/llvm/ext/llvm_ext.o

release ?=      ## Compile in release mode
progress = 1    ## Enable progress output
threads ?=      ## Maximum number of threads to use
debug ?=        ## Add symbolic debug info
verbose ?=      ## Run specs in verbose mode
static ?=       ## Enable static linking
order ?=random  ## Enable order for spec execution (values: "default" | "random" | seed number)

.PHONY: all
all: build
#	install -m 644 man/crystal.1.gz "/usr/share/man/man1/crystal.1.gz"

.PHONY: hello
hello:
	build -p -r -o hello test/hello.cr
	./hello

.PHONY: build
build: $(LLVM_EXT_OBJ) ## Build the compiler
	build --progress -o $@ src/build.cr
	mv build $(HOME)/bin/

.PHONY: crystal
crystal: clean $(LLVM_EXT_OBJ) ## Build the compiler
	crystal build -D strict_multi_assign -D preview_overload_order --progress --stats -o build src/build.cr
	mv build $(HOME)/bin/

$(LLVM_EXT_OBJ): $(LLVM_EXT_SRC)
	$(CXX) -c $(LLVM_CXXFLAGS) -o llvm_ext.o $<
	sudo mv llvm_ext.o $@

.PHONY: man
man: man/crystal.1.gz ## Build the manual

man/%.gz: man/%
	gzip -c -9 $< > $@

.PHONY: clean
clean: ## Clean up built directories and files
	rm -rf ~/.cache/crystal/*
	find ./ -name "*~" -delete

.PHONY: test
test:
	@for file in $$(ls -1 test/test_*.cr); do \
    echo "" ; \
    echo "Compiling $${file}" ; \
    build -q -o test_unit $${file} ; \
    echo "Running:" ; \
	  ./test_unit ; \
    rm -f test_unit ; \
  done

.PHONY: help
help: ## Show this help
	@echo
	@printf '\033[34mTargets:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34mOptional variables:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+ \?=.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = " \\?=.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34mRecipes:\033[0m\n'
	@grep -hE '^##.*$$' $(MAKEFILE_LIST) |\
		awk 'BEGIN {FS = "## "}; /^## [a-zA-Z_-]/ {printf "  \033[36m%s\033[0m\n", $$2}; /^##  / {printf "  %s\n", $$2}'
