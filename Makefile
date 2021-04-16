export GO111MODULE=on

VERSION := $(shell echo $(shell git describe --tags) | sed 's/^v//')
TM_VERSION := $(shell go list -m github.com/tendermint/tendermint | sed 's:.* ::')
COMMIT := $(shell git rev-parse --short HEAD)

include sims.mk

build_tags = netgo,ledger
build_tags_comma_sep := $(subst $(whitespace),$(comma),$(build_tags))

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=persistenceCore \
		  -X github.com/cosmos/cosmos-sdk/version.AppName=persistenceCore \
		  -X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
		  -X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
		   -X github.com/tendermint/tendermint/version.TMCoreSemVer=$(TM_VERSION) \
		  -X github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags_comma_sep)

ifeq (cleveldb,$(findstring cleveldb,$(build_tags)))
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=cleveldb
endif
ifeq (badgerdb,$(findstring badgerdb,$(build_tags)))
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=badgerdb
endif
ifeq (rocksdb,$(findstring rocksdb,$(build_tags)))
  CGO_ENABLED=1
endif

BUILD_FLAGS += -ldflags "${ldflags}" -tags "${build_tags}"

GOBIN = $(shell go env GOPATH)/bin
GOARCH = $(shell go env GOARCH)
GOOS = $(shell go env GOOS)

all: verify build

install:
ifeq (${OS},Windows_NT)
	go build -mod=readonly ${BUILD_FLAGS} -o ${GOBIN}/persistenceCore.exe ./node

else
	go build -mod=readonly ${BUILD_FLAGS} -o ${GOBIN}/persistenceCore ./node

endif

build:
ifeq (${OS},Windows_NT)
	go build  ${BUILD_FLAGS} -o build/${GOOS}/${GOARCH}/persistenceCore.exe ./node

else
	go build  ${BUILD_FLAGS} -o build/${GOOS}/${GOARCH}/persistenceCore ./node

endif

verify:
	@echo "verifying modules"
	@go mod verify

.PHONY: all install build verify

release: build
	mkdir -p release
ifeq (${OS},Windows_NT)
	tar -czvf release/persistenceCore-${GOOS}-${GOARCH}.tar.gz --directory=build/${GOOS}/${GOARCH} persistenceCore.exe
else
	tar -czvf release/persistenceCore-${GOOS}-${GOARCH}.tar.gz --directory=build/${GOOS}/${GOARCH} persistenceCore
endif
	 

clean:
	rm -rf build release

DOCKER := $(shell which docker)

proto-gen:
	@echo "Generating Protobuf files"
	$(DOCKER) run --rm -v $(shell go list -f "{{ .Dir }}" \
	-m github.com/cosmos/cosmos-sdk):/workspace/cosmos_sdk_dir\
	 --env COSMOS_SDK_DIR=/workspace/cosmos_sdk_dir \
	 -v $(CURDIR):/workspace --workdir /workspace \
	 tendermintdev/sdk-proto-gen sh ./.script/protocgen.sh
