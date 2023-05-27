STX_BUILD=jpm_tree/lib/stx/init.janet
STX_TEST_DEP=jpm_tree/bin/judge
STX_TEST_CMD=jpm_tree/bin/judge

all: build test

$(STX_TEST_DEP):
	jpm install --local git::https://github.com/ianthehenry/judge.git::v2.5.0

$(STX_BUILD): project.janet src/init.janet src/stx.c
	jpm install --local

build: $(STX_BUILD)

clean:
	rm -rf jpm_tree/

test: build $(STX_TEST_DEP)
	jpm -l exec $(STX_TEST_CMD) test/

.PHONY: all build clean test
