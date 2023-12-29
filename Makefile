# Recipes for this Makefile

## Build the compiler
##   $ make
## Build the compiler with progress output
##   $ make progress=1
## Build the compiler in release mode
##   $ make release=1
## Clean up built files
##   $ make clean
## Run tests
##   $ make test
## Run stdlib tests
##   $ make std_spec
## Run compiler tests
##   $ make compiler_spec

#export CRYSTAL_CACHE_DIR := cache
export CRYSTAL_PATH      := src:lib
#export CRYSTAL_LIBRARY_PATH := lib

# llvm-config command path to use
LLVM_CXXFLAGS := $(shell llvm-config-12 --cxxflags)
LLVM_EXT_SRC := lib/llvm/ext/llvm_ext.cc
LLVM_EXT_OBJ := lib/llvm/ext/llvm_ext.o

release ?=      ## Compile in release mode
progress = 1    ## Enable progress output
threads ?=      ## Maximum number of threads to use
debug ?=        ## Add symbolic debug info
verbose ?=      ## Run specs in verbose mode
static ?=       ## Enable static linking
order ?=random  ## Enable order for spec execution (values: "default" | "random" | seed number)

FLAGS := -D strict_multi_assign -D preview_overload_order --progress

#CC = "cc -fuse-ld=lld -l$(LLVM_EXT_OBJ)"
CXXFLAGS += $(if $(debug),-g -O0)

.PHONY: all
all: build
#	install -m 644 man/crystal.1.gz "/usr/share/man/man1/crystal.1.gz"

.PHONY: spec
spec:
	@for file in spec/spec_*.cr ; do \
    echo "" ; \
    echo "Compiling $${file}" ; \
    build -q -o cache/ts $${file} ; \
    echo "Running:" ; \
    ./cache/ts ; \
	  rm -f cache/ts ; \
  done

.PHONY: test
test:
	@echo "Build"
	@build -q -o cache/tu test/test.cr
	@./cache/tu
	@rm -f cache/tu

.PHONY: hello
hello:
	build -p -r -o hello test/hello.cr
	./hello

.PHONY: build
build: $(LLVM_EXT_OBJ) ## Build the compiler
	build $(FLAGS) -o $@ src/build.cr
	mv build $(HOME)/bin/

.PHONY: crystal
crystal: $(LLVM_EXT_OBJ) ## Build the compiler
	crystal build $(FLAGS) -o build src/build.cr
	mv build $(HOME)/bin/


$(LLVM_EXT_OBJ): $(LLVM_EXT_SRC)
	$(CXX) -c $(CXXFLAGS) -o $@ $< $(LLVM_CXXFLAGS)

.PHONY: man
man: man/crystal.1.gz ## Build the manual

man/%.gz: man/%
	gzip -c -9 $< > $@

.PHONY: clean
clean: ## Clean up built directories and files
	rm -rf cache/*
	find ./ -name "*~" -delete

#.PHONY: test
#test: spec ## Run tests

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
