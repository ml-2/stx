all: build test

jpm_tree/bin/judge:
	jpm install --local git::https://github.com/ianthehenry/judge.git::v2.5.0

jpm_tree/lib/stx/init.janet: project.janet src/init.janet src/stx.c
	jpm install --local

build: jpm_tree/lib/stx/init.janet

clean:
	rm -rf jpm_tree/

test: jpm_tree/lib/stx/init.janet jpm_tree/bin/judge
	jpm -l exec jpm_tree/bin/judge test/

.PHONY: all build clean test
