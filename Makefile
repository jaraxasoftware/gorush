DIST := dist
EXECUTABLE := gorush

GO ?= go
DEPLOY_ACCOUNT := jaraxasoftware
DEPLOY_IMAGE := $(EXECUTABLE)
CONTAINER := js-gorush
PORT := 8088
GOFMT ?= gofmt "-s"
EXTERNAL_TOOLS=\
	github.com/mitchellh/gox \
	github.com/kardianos/govendor

TARGETS ?= linux darwin windows
ARCHS ?= amd64 386
PACKAGES ?= $(shell $(GO) list ./... | grep -v /vendor/)
GOFILES := $(shell find . -name "*.go" -type f -not -path "./vendor/*")
SOURCES ?= $(shell find . -name "*.go" -type f)
TAGS ?=
LDFLAGS ?= -X 'main.Version=$(VERSION)'
TMPDIR := $(shell mktemp -d 2>/dev/null || mktemp -d -t 'tempdir')
NODE_PROTOC_PLUGIN := $(shell which grpc_tools_node_protoc_plugin)

ifneq ($(shell uname), Darwin)
	EXTLDFLAGS = -extldflags "-static" $(null)
else
	EXTLDFLAGS =
endif

ifneq ($(DRONE_TAG),)
	VERSION ?= $(DRONE_TAG)
else
	VERSION ?= $(shell git describe --tags --always || git rev-parse --short HEAD)
endif

.PHONY: all
all: build

init:
ifeq ($(ANDROID_API_KEY),)
	@echo "Missing ANDROID_API_KEY Parameter"
	@exit 1
endif
ifeq ($(ANDROID_TEST_TOKEN),)
	@echo "Missing ANDROID_TEST_TOKEN Parameter"
	@exit 1
endif
	@echo "Already set ANDROID_API_KEY and ANDROID_TEST_TOKEN globale variable."

# bootstrap the build by downloading additional tools
bootstrap:
	@for tool in  $(EXTERNAL_TOOLS) ; do \
		echo "Installing/Updating $$tool" ; \
		go get -u $$tool; \
	done

fmt:
	$(GOFMT) -w $(GOFILES)

.PHONY: fmt-check
fmt-check:
	@diff=$$($(GOFMT) -d $(GOFILES)); \
	if [ -n "$$diff" ]; then \
		echo "Please run 'make fmt' and commit the result:"; \
		echo "$${diff}"; \
		exit 1; \
	fi;

vet:
	$(GO) vet $(PACKAGES)

deps:
	$(GO) get github.com/campoy/embedmd

embedmd:
	embedmd -d *.md

errcheck:
	@hash errcheck > /dev/null 2>&1; if [ $$? -ne 0 ]; then \
		$(GO) get -u github.com/kisielk/errcheck; \
	fi
	errcheck $(PACKAGES)

lint:
	@hash golint > /dev/null 2>&1; if [ $$? -ne 0 ]; then \
		$(GO) get -u github.com/golang/lint/golint; \
	fi
	for PKG in $(PACKAGES); do golint -set_exit_status $$PKG || exit 1; done;

unconvert:
	@hash unconvert > /dev/null 2>&1; if [ $$? -ne 0 ]; then \
		$(GO) get -u github.com/mdempsky/unconvert; \
	fi
	for PKG in $(PACKAGES); do unconvert -v $$PKG || exit 1; done;

# Install from source.
install: $(SOURCES)
	$(GO) install -v -tags '$(TAGS)' -ldflags '$(EXTLDFLAGS)-s -w $(LDFLAGS)'
	@echo "==> Installed gorush ${GOPATH}/bin/gorush"
.PHONY: install

# build from source
build: $(EXECUTABLE)
.PHONY: build

$(EXECUTABLE): $(SOURCES)
	$(GO) build -v -tags '$(TAGS)' -ldflags '$(EXTLDFLAGS)-s -w $(LDFLAGS)' -o bin/$@

.PHONY: misspell-check
misspell-check:
	@hash misspell > /dev/null 2>&1; if [ $$? -ne 0 ]; then \
		$(GO) get -u github.com/client9/misspell/cmd/misspell; \
	fi
	misspell -error $(GOFILES)

.PHONY: misspell
misspell:
	@hash misspell > /dev/null 2>&1; if [ $$? -ne 0 ]; then \
		$(GO) get -u github.com/client9/misspell/cmd/misspell; \
	fi
	misspell -w $(GOFILES)

test: fmt-check
	for PKG in $(PACKAGES); do $(GO) test -v -cover -coverprofile $$GOPATH/src/$$PKG/coverage.txt $$PKG || exit 1; done;

.PHONY: test-vendor
test-vendor:
	@hash govendor > /dev/null 2>&1; if [ $$? -ne 0 ]; then \
		$(GO) get -u github.com/kardianos/govendor; \
	fi
	govendor list +unused | tee "$(TMPDIR)/wc-gitea-unused"
	[ $$(cat "$(TMPDIR)/wc-gitea-unused" | wc -l) -eq 0 ] || echo "Warning: /!\\ Some vendor are not used /!\\"

	govendor list +outside | tee "$(TMPDIR)/wc-gitea-outside"
	[ $$(cat "$(TMPDIR)/wc-gitea-outside" | wc -l) -eq 0 ] || exit 1

	govendor status || exit 1

redis_test: init
	$(GO) test -v -cover ./storage/redis/...

boltdb_test: init
	$(GO) test -v -cover ./storage/boltdb/...

memory_test: init
	$(GO) test -v -cover ./storage/memory/...

buntdb_test: init
	$(GO) test -v -cover ./storage/buntdb/...

leveldb_test: init
	$(GO) test -v -cover ./storage/leveldb/...

config_test: init
	$(GO) test -v -cover ./config/...

html:
	$(GO) tool cover -html=.cover/coverage.txt

release: release-dirs release-build release-copy release-check

release-dirs:
	mkdir -p $(DIST)/binaries $(DIST)/release

release-build:
	@hash gox > /dev/null 2>&1; if [ $$? -ne 0 ]; then \
		$(GO) get -u github.com/mitchellh/gox; \
	fi
	gox -os="$(TARGETS)" -arch="$(ARCHS)" -tags="$(TAGS)" -ldflags="$(EXTLDFLAGS)-s -w $(LDFLAGS)" -output="$(DIST)/binaries/$(EXECUTABLE)-$(VERSION)-{{.OS}}-{{.Arch}}"

release-copy:
	$(foreach file,$(wildcard $(DIST)/binaries/$(EXECUTABLE)-*),cp $(file) $(DIST)/release/$(notdir $(file));)

release-check:
	cd $(DIST)/release; $(foreach file,$(wildcard $(DIST)/release/$(EXECUTABLE)-*),sha256sum $(notdir $(file)) > $(notdir $(file)).sha256;)

docker_build:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GO) build -a -tags '$(TAGS)' -ldflags "$(EXTLDFLAGS)-s -w $(LDFLAGS)" -o bin/$(EXECUTABLE)

docker_build_arm64:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 $(GO) build -a -tags '$(TAGS)' -ldflags "$(EXTLDFLAGS)-s -w $(LDFLAGS)" -o bin/$(EXECUTABLE)-arm64

docker_build_arm:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 $(GO) build -a -tags '$(TAGS)' -ldflags "$(EXTLDFLAGS)-s -w $(LDFLAGS)" -o bin/$(EXECUTABLE)-arm

docker_image:
	docker build -t $(DEPLOY_ACCOUNT)/$(DEPLOY_IMAGE) -f Dockerfile .

docker_release: docker_build docker_image

docker_deploy:
ifeq ($(tag),)
	@echo "Usage: make $@ tag=<tag>"
	@exit 1
endif
	docker tag $(DEPLOY_ACCOUNT)/$(EXECUTABLE):latest $(DEPLOY_ACCOUNT)/$(EXECUTABLE):$(tag)
	docker push $(DEPLOY_ACCOUNT)/$(EXECUTABLE):$(tag)

docker_stop:
	@if [ $(shell docker ps -a | grep -ci $(CONTAINER)) -eq 1 ]; then \
		docker stop $(CONTAINER) > /dev/null 2>&1; \
	fi

docker_rm: docker_stop
	@if [ $(shell docker ps -a | grep -ci $(CONTAINER)) -eq 1 ]; then \
		docker rm $(CONTAINER) > /dev/null 2>&1; \
	fi

docker_rmi: docker_rm
ifeq ($(tag),)
	@if [ $(shell docker images | grep -ci $(DEPLOY_ACCOUNT)/$(EXECUTABLE)) -eq 1 ]; then \
		docker rmi $(DEPLOY_ACCOUNT)/$(EXECUTABLE):latest > /dev/null 2>&1; \
	fi;
	@if [ $(shell docker images | grep -ci centurylink/ca-certs) -eq 1 ]; then \
		docker rmi centurylink/ca-certs:latest > /dev/null 2>&1; \
	fi
else
	@if [ $(shell docker images | grep -ci $(DEPLOY_ACCOUNT)/$(EXECUTABLE)) -eq 1 ]; then \
		docker rmi $(DEPLOY_ACCOUNT)/$(EXECUTABLE):$(tag) > /dev/null 2>&1; \
	fi;
	@if [ $(shell docker images | grep -ci centurylink/ca-certs) -eq 1 ]; then \
		docker rmi centurylink/ca-certs:latest > /dev/null 2>&1; \
	fi
endif

docker_run: docker_rm
	docker run -ti -d --name $(CONTAINER) --restart always \
	-p ${PORT}:8088 \
	-v ${CURDIR}/config:/config:ro \
	$(DEPLOY_ACCOUNT)/$(EXECUTABLE):latest /gorush -c /config/config.yml

docker_test:
	curl \
	-XGET \
	-H "Accept: application/json" \
 	"localhost:$(PORT)/api/stat/go" | python -mjson.tool

docker_save:
	docker save $(DEPLOY_ACCOUNT)/$(EXECUTABLE) | gzip > $(DEPLOY_ACCOUNT)_$(EXECUTABLE).tar.gz

docker_load:
	gunzip < $(DEPLOY_ACCOUNT)_$(EXECUTABLE).tar.gz | docker load

docker_zip_only:
	cp $(DEPLOY_ACCOUNT)_$(EXECUTABLE).tar.gz scripts/$(DEPLOY_ACCOUNT)_$(EXECUTABLE).tar.gz;
	cp envs scripts/envs;
	cp build.sh scripts/build.sh;
	cp remove.sh scripts/remove.sh;
	cp start.sh scripts/start.sh;
	cp stop.sh scripts/stop.sh;
	cp test.sh scripts/test.sh;
	rm -f scripts/.DS_Store;
	rm -f gorush.zip;
	cd scripts; zip -r -X ../gorush.zip .

docker_zip: clean docker_rmi docker_build docker_image docker_run docker_test docker_save docker_rmi docker_zip_only
	# !IMPORTANT: Check the test output before using gorush.zip file

clean:
	$(GO) clean -x -i ./...
	find . -name coverage.txt -delete
	find . -name *.tar.gz -delete
	find . -name *.db -delete
	-rm -rf bin dist .cover

rpc/example/node/gorush_*_pb.js: rpc/proto/gorush.proto
	protoc -I rpc/proto rpc/proto/gorush.proto --js_out=import_style=commonjs,binary:rpc/example/node/ --grpc_out=rpc/example/node/ --plugin=protoc-gen-grpc=$(NODE_PROTOC_PLUGIN)

rpc/proto/gorush.pb.go: rpc/proto/gorush.proto
	protoc -I rpc/proto rpc/proto/gorush.proto --go_out=plugins=grpc:rpc/proto

generate_proto: rpc/proto/gorush.pb.go rpc/example/node/gorush_*_pb.js

version:
	@echo $(VERSION)
