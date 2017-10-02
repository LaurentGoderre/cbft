CBFT_CHECKOUT = origin/master
CBFT_DOCKER   = cbft-builder:latest
CBFT_OUT      = ./cbft
CBFT_TAGS     =

pwd     = $(shell pwd)
version = $(shell git describe --long)
goflags = -ldflags '-X main.VERSION=$(version)' \
          -tags "debug kagome $(CBFT_TAGS)"

# -------------------------------------------------------------------
# Targets commonly used for day-to-day development...

default: build

clean:
	rm -f ./cbft ./cbft_docs

build: gen-bindata
	go build $(goflags) -o $(CBFT_OUT) ./cmd/cbft

build-static:
	$(MAKE) build CBFT_TAGS="libstemmer"

build-leveldb:
	$(MAKE) build CBFT_TAGS="libstemmer icu leveldb"

build-full:
	$(MAKE) build CBFT_TAGS="full"

gen-bindata:
	go-bindata-assetfs -pkg=cbft ./staticx/... ./ns_server_static/fts/static-bleve-mapping/...
	gofmt -s -w bindata_assetfs.go

gen-docs: cmd/cbft_docs/main.go
	go build $(goflags) -o ./cbft_docs ./cmd/cbft_docs
	./cbft_docs > docs/api-ref.md
	./dist/gen-command-docs > docs/admin-guide/command.md

test:
	go test -v -tags "debug kagome $(CBFT_TAGS)" .
	go test -v -tags "debug kagome $(CBFT_TAGS)" ./cmd/cbft

test-full:
	$(MAKE) test CBFT_TAGS="full"

coverage:
	go test -tags "debug kagome $(CBFT_TAGS)" -coverprofile=coverage.out -covermode=count
	go tool cover -html=coverage.out

# -------------------------------------------------------------------
# Release / distribution related targets...

dist: test dist-meta dist-build

dist-meta:
	mkdir -p ./dist/out
	mkdir -p ./staticx/dist
	rm -rf ./dist/out/*
	rm -rf ./staticx/dist/*
	echo $(version) > ./staticx/dist/version.txt
	cp ./staticx/dist/version.txt ./dist/out
	./dist/go-manifest > ./staticx/dist/manifest.txt
	cp ./staticx/dist/manifest.txt ./dist/out
	cp ./LICENSE.txt ./staticx/dist/LICENSE.txt
	cp ./staticx/dist/LICENSE.txt ./dist/out
	cp ./LICENSE-thirdparty.txt ./dist/out
	cp ./CHANGES.md ./dist/out

dist-build:
	$(MAKE) build        GOOS=darwin  GOARCH=amd64       CBFT_OUT=./dist/out/cbft.macos.amd64
	# $(MAKE) build      GOOS=linux   GOARCH=386         CBFT_OUT=./dist/out/cbft.linux.386
	$(MAKE) build        GOOS=linux   GOARCH=arm         CBFT_OUT=./dist/out/cbft.linux.arm
	$(MAKE) build        GOOS=linux   GOARCH=arm GOARM=5 CBFT_OUT=./dist/out/cbft.linux.arm5
	$(MAKE) build        GOOS=linux   GOARCH=amd64       CBFT_OUT=./dist/out/cbft.linux.amd64
	$(MAKE) build        GOOS=freebsd GOARCH=amd64       CBFT_OUT=./dist/out/cbft.freebsd.amd64
	# $(MAKE) build      GOOS=windows GOARCH=386         CBFT_OUT=./dist/out/cbft.windows.386.exe
	$(MAKE) build        GOOS=windows GOARCH=amd64       CBFT_OUT=./dist/out/cbft.windows.amd64.exe

dist-clean: clean
	rm -rf ./dist/out/*
	rm -rf ./staticx/dist/*
	git checkout bindata_assetfs.go

manifest.projects: dist-meta
	awk '{split($$1, a, "/"); printf "  <project revision=\"%s\" path=\"%s\" name=\"%s\"/>\n", $$2, $$1, a[length(a)];}' ./dist/out/manifest.txt > ./dist/out/manifest.projects

# The release target prerequisites...
#
# - A cbft-builder docker image.
#
# See: ./dist/Dockerfile
#
# - Access tokens to be able to publish releases on couchbase/cbft...
#
#   export GITHUB_TOKEN=/* a github access token */
#   export GITHUB_USER=couchbase
#
# See: https://help.github.com/articles/creating-an-access-token-for-command-line-use
#
# To release a new version...
#
#   git describe    # Find the current version.
#   git grep v0.0.1 # Look for old version strings.
#   git grep v0.0   # Look for old version strings.
#   # Edit/update files, especially cmd/cbft/main.go and mkdocs.yml...
#   # Then, ensure that bindata_assetfs.go is up-to-date, by running...
#   make build
#   # Then, run tests, gen-docs, etc...
#   make test
#   make gen-docs
#   # Then, run a diff against the previous version...
#   git log --pretty=format:%s v0.0.1...
#   # Then, update the CHANGES.md file based on diff.
#   git commit -m "v0.0.2"
#   git push
#   git tag -a "v0.0.2" -m "v0.0.2"
#   git push --tags
#   # Don't forget to set your GITHUB_TOKEN/USER env vars; see above.
#   make release
#
# Remember, we use semver versioning rules.
#
# Of note, the version.go/VERSION is only updated on data/config format changes.
#
release: release-build \
	release-github-register release-github-upload release-github-docs

release-build:
	mkdir -p ./tmp/dist-out
	mkdir -p ./tmp/dist-site
	rm -rf ./tmp/dist-out/*
	rm -rf ./tmp/dist-site/*
	docker run --rm \
		-v $(pwd)/tmp/dist-out:/tmp/dist-out \
		-v $(pwd)/tmp/dist-site:/tmp/dist-site \
		$(CBFT_DOCKER) \
		make -C /go/src/github.com/couchbase/cbft \
			CBFT_CHECKOUT=$(CBFT_CHECKOUT) \
			release-build-helper dist-clean
	(cd ./tmp/dist-out; for f in *.exe; do \
		zip $$f.zip $$f; \
	done)
	(cd ./tmp/dist-out; for f in *.amd64; do \
		tar -zcvf $$f.tar.gz $$f; \
	done)

release-build-helper: # This runs inside a cbft-builder docker container.
	git remote update
	git fetch --tags
	git checkout $(CBFT_CHECKOUT)
	$(MAKE) dist
	$(MAKE) gen-docs
	mkdocs build --clean
	mkdir -p /tmp/dist-out
	mkdir -p /tmp/dist-site
	rm -rf /tmp/dist-out/*
	rm -rf /tmp/dist-site/*
	cp -R ./dist/out/* /tmp/dist-out
	cp -R ./site/* /tmp/dist-site

release-github-register:
	$(GOPATH)/bin/github-release --verbose release \
		--repo cbft \
		--tag $(strip $(shell git describe --abbrev=0 --tags \
				$(strip $(shell cat ./tmp/dist-out/version.txt)))) \
		--pre-release

release-github-upload:
	(cd ./tmp/dist-out; for f in *.gz *.zip *.md *.txt; do \
		echo $$f | \
			sed -e s/\\./-$(strip $(shell cat ./tmp/dist-out/version.txt))\\./1 | \
			xargs $(GOPATH)/bin/github-release upload \
				--file $$f \
				--repo cbft \
				--tag $(strip $(shell git describe --abbrev=0 --tags \
						$(strip $(shell cat ./tmp/dist-out/version.txt)))) --name; done)

release-github-docs:
	rm -rf ./site/*
	cp -R ./tmp/dist-site/* ./site
	mkdocs gh-deploy

# -------------------------------------------------------------------

LICENSE-thirdparty.txt:
	./dist/go-manifest | ./dist/gen-license-thirdparty > LICENSE-thirdparty.txt

# -------------------------------------------------------------------
# The prereqs are for one time setup of required build/dist tools...

prereqs:
	go get github.com/blevesearch/bleve/...
	go get github.com/blevesearch/bleve-mapping-ui/...
	go get github.com/jteeuwen/go-bindata/...
	go get github.com/elazarl/go-bindata-assetfs/...
	go get github.com/ikawaha/kagome/...
	go get github.com/tebeka/snowball/...

prereqs-dist: prereqs
	go get github.com/aktau/github-release/...
	pip install mkdocs
