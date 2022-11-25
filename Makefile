.DEFAULT_GOAL := default
MAIN_BIN_FILE="innsecure"
TOKEN_BIN_FILE="token"
DOCKER_IMAGE_BUILD="form3/innsecure"
DOCKER_BUILDKIT=1

PROJECT_NAME := "innsecure"
PKG := "$(PROJECT_NAME)"
PKG_LIST := $(shell go list ${PKG}/... | grep -v /vendor/)
GO_FILES := $(shell find . -name '*.go')

VERSION := $(shell cat version.txt)
TIME := $(shell date)

PLATFORM=local
GO111MODULE=on

LINTER := github.com/kisielk/errcheck@latest
SAST := honnef.co/go/tools/cmd/staticcheck@latest
CHANGELOG := github.com/git-chglog/git-chglog/cmd/git-chglog@latest

clean:
		@rm ./bin/*

sast:   install-deps ## Perform basic static code checks.
		@staticcheck

lint:   install-deps ## Lint the golang files
		@errcheck ./...

race:   ## Run data race detector
		@go test -race -short ./...

msan:   ## Run memory sanitizer
		@go test -msan -short ./...

changelog: install-deps
		@mkdir -p ~/.config/git-chglog/
		@touch ~/.config/git-chglog/config.yml
		@git-chglog  -c ~/.config/git-chglog/config.yml -o CHANGELOG.md --next-tag 'semtag final -s minor -o'


default: build test

build: install-deps sast race
		@go build -o ${MAIN_BIN_FILE} ./cmd/innsecure
		@go build -o ${TOKEN_BIN_FILE} ./cmd/token

bin_dir:
		@mkdir -p ./bin

install-deps: install-goimports install-sast install-linter install-changelog

install-goimports:
		@if [ ! -f ./goimports ]; then \
                cd ~ && go install golang.org/x/tools/cmd/goimports@latest; \
		fi

install-sast:
		@go install -v ${SAST}

install-linter:
		@go install -v $(LINTER)

install-changelog:
		@go install -v $(CHANGELOG)

install-kind:
		@go install sigs.k8s.io/kind@v0.13.0

install: bin_dir
		@go install ./cmd/innsecure

test:
		@echo "executing tests..."
		@go test github.com/form3tech/innsecure

# package for release to candidates (ignore for test exercise)
package-%:
		@echo $*
		@cd .. && pwd && tar -czvf innsecure-$*.tar.gz --exclude={".git",".github","bin","releases"} ${MAIN_BIN_FILE}
		@mkdir -p releases
		@mv ../innsecure-$*.tar.gz releases

get-docker-images:
		@docker build . -t ${DOCKER_IMAGE_BUILD}
		@docker pull postgres:12

start-kind: install-kind get-docker-images
		@kind create cluster
		@kind load docker-image ${DOCKER_IMAGE_BUILD}
		@kind load docker-image postgres:12
		@kubectl apply -f ./k8s/secret-controller.yaml
		@kubectl wait --for condition=established crd sealedsecrets.bitnami.com
		@kubectl apply -f ./k8s/base-config.yaml
		@kubectl apply -f ./k8s/sealed-innsecure-secrets.yaml
		@kubectl apply -f ./k8s/postgres.yaml
		@kubectl apply -f ./k8s/innsecure.yaml


stop-kind:
		@kind delete cluster
		@docker image rm ${DOCKER_IMAGE_BUILD}

run:
		@./${MAIN_BIN_FILE}

.PHONY: clean build test package-% get-docker-images start-kind stop-kind run