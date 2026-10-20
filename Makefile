#
# Copyright 2022 Ivo Woltring <WebMaster@ivonet.nl>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# You can override the default config with `make cnf=config_special.env build`.
cnf ?= makefile.env
include $(cnf)
export $(shell sed 's/=.*//' $(cnf))

PODMAN ?= podman
DOCKERFILES := $(wildcard */Dockerfile)
IMAGES := $(patsubst %/Dockerfile,%,$(DOCKERFILES))
RELEASE_IMAGE_TARGETS := $(addprefix release-,$(IMAGES))
TAG_IMAGE_TARGETS := $(addprefix tag-,$(IMAGES))
MULTI_IMAGE_TARGETS := $(addprefix multi-,$(IMAGES))
X86_TARGETS := $(addprefix x86-,$(IMAGES))
NO_CACHE_TARGETS := $(addprefix nc-,$(IMAGES))

.PHONY: help projects build build-nc tag versioning version release publish \
	publish-latest publish-version clean cleaner cleanest dangling rmi \
	rmi-version rmi-latest rmi-base-images rmc stop prune buildx rmbuildx \
	$(IMAGES) $(RELEASE_IMAGE_TARGETS) $(TAG_IMAGE_TARGETS) \
	$(MULTI_IMAGE_TARGETS) $(X86_TARGETS) $(NO_CACHE_TARGETS)

.DEFAULT_GOAL := help

help: projects ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

projects: ## Print the projects that have build targets
	@for project in $(IMAGES); do \
		printf "\033[36m%-30s\033[0m Builds %s\n" "$$project" "$$project"; \
		printf "\033[36mtag-%-26s\033[0m Tags %s\n" "$$project" "$$project"; \
		printf "\033[36mrelease-%-22s\033[0m Releases %s\n" "$$project" "$$project"; \
		printf "\033[36mmulti-%-24s\033[0m multi-platform release %s\n" "$$project" "$$project"; \
		printf "\033[36mnc-%-27s\033[0m no-cache build %s\n" "$$project" "$$project"; \
		printf "\033[36mx86-%-27s\033[0m linux/amd64 release %s\n" "$$project" "$$project"; \
	done

$(IMAGES): %: ## Build a project by its directory name
	@project="$@"; \
	preparation_script="$$project/pre-make.sh"; \
	make_script="$$project/make.sh"; \
	if [ -f "$$preparation_script" ]; then \
		echo "Using pre-make.sh script for preparation..."; \
		(cd "$$project" && bash ./pre-make.sh) || exit $$?; \
	fi; \
	if [ -f "$$make_script" ]; then \
		echo "Using the make.sh instead of the standard build"; \
		(cd "$$project" && bash ./make.sh); \
	else \
		$(PODMAN) build $(ARG) --platform=linux/arm64/v8 -t $(REGISTRY)/$@ "$$project"; \
	fi

$(NO_CACHE_TARGETS): nc-%: ## Build a project without using the cache
	@project="$*"; \
	preparation_script="$$project/pre-make.sh"; \
	if [ -f "$$preparation_script" ]; then \
		echo "Using pre-make.sh script for preparation..."; \
		(cd "$$project" && bash ./pre-make.sh) || exit $$?; \
	fi; \
	$(PODMAN) build --no-cache -t $(REGISTRY)/$$project "$$project"

$(RELEASE_IMAGE_TARGETS): release-%: ## Build and publish one project
	@project="$*"; \
	versionfile="$$project/VERSION"; \
	MY_APP_VERSION="$(VERSION)"; \
	if [ -f "$$versionfile" ]; then MY_APP_VERSION=$$(cat "$$versionfile"); fi; \
	preparation_script="$$project/pre-make.sh"; \
	if [ -f "$$preparation_script" ]; then \
		echo "Using pre-make.sh script for preparation..."; \
		(cd "$$project" && bash ./pre-make.sh) || exit $$?; \
	fi; \
	$(PODMAN) build -t $(REGISTRY)/$$project "$$project" && \
	$(PODMAN) tag $(REGISTRY)/$$project:latest $(REGISTRY)/$$project:$$MY_APP_VERSION && \
	$(PODMAN) push $(REGISTRY)/$$project:latest && \
	$(PODMAN) push $(REGISTRY)/$$project:$$MY_APP_VERSION

$(MULTI_IMAGE_TARGETS): multi-%: buildx ## Build and publish a multi-platform manifest
	@project="$*"; \
	versionfile="$$project/VERSION"; \
	MY_APP_VERSION="$(VERSION)"; \
	if [ -f "$$versionfile" ]; then MY_APP_VERSION=$$(cat "$$versionfile"); fi; \
	preparation_script="$$project/pre-make.sh"; \
	if [ -f "$$preparation_script" ]; then \
		echo "Using pre-make.sh script for preparation..."; \
		(cd "$$project" && bash ./pre-make.sh) || exit $$?; \
	fi; \
	for tag in latest "$$MY_APP_VERSION"; do \
		image="$(REGISTRY)/$$project:$$tag"; \
		$(PODMAN) build $(ARG) --no-cache --platform=linux/amd64 --manifest "$$image" "$$project" || exit $$?; \
		$(PODMAN) build $(ARG) --no-cache --platform=linux/arm64/v8 --manifest "$$image" "$$project" || exit $$?; \
		$(PODMAN) manifest push --all "$$image" "docker://$$image" || exit $$?; \
	done; \
	$(PODMAN) pull $(REGISTRY)/$$project:latest

$(X86_TARGETS): x86-%: buildx ## Build and publish a linux/amd64 image
	@project="$*"; \
	versionfile="$$project/VERSION"; \
	MY_APP_VERSION="$(VERSION)"; \
	if [ -f "$$versionfile" ]; then MY_APP_VERSION=$$(cat "$$versionfile"); fi; \
	preparation_script="$$project/pre-make.sh"; \
	if [ -f "$$preparation_script" ]; then \
		echo "Using pre-make.sh script for preparation..."; \
		(cd "$$project" && bash ./pre-make.sh) || exit $$?; \
	fi; \
	$(PODMAN) build --no-cache --platform=linux/amd64 -t $(REGISTRY)/$$project:latest "$$project" && \
	$(PODMAN) push $(REGISTRY)/$$project:latest && \
	$(PODMAN) tag $(REGISTRY)/$$project:latest $(REGISTRY)/$$project:$$MY_APP_VERSION && \
	$(PODMAN) push $(REGISTRY)/$$project:$$MY_APP_VERSION

$(TAG_IMAGE_TARGETS): tag-%: ## Tag a project image with its version
	@project="$*"; \
	versionfile="$$project/VERSION"; \
	MY_APP_VERSION="$(VERSION)"; \
	if [ -f "$$versionfile" ]; then \
		MY_APP_VERSION=$$(cat "$$versionfile"); \
		echo "$(REGISTRY)/$$project version override: $$MY_APP_VERSION"; \
	fi; \
	echo "Tagging $(REGISTRY)/$$project as: $$MY_APP_VERSION"; \
	$(PODMAN) tag $(REGISTRY)/$$project:latest $(REGISTRY)/$$project:$$MY_APP_VERSION

# Kept as a compatibility target: Podman builds do not need a separate builder.
buildx: ## Check that Podman is available (no builder setup is required)
	@$(PODMAN) info >/dev/null

prune: ## Prune unused Podman data
	@echo "Pruning the Podman system..."; \
	$(PODMAN) system prune -f

rmbuildx: prune ## Compatibility target; Podman has no separate Buildx builder
	@echo "Podman does not use a separate Buildx builder."

build: ## Build all project images as 'latest'
	@for img in $(IMAGES); do \
		project="$$img"; \
		preparation_script="$$project/pre-make.sh"; \
		if [ -f "$$preparation_script" ]; then \
			echo "Using pre-make.sh script for preparation..."; \
			(cd "$$project" && bash ./pre-make.sh) || exit $$?; \
		fi; \
		$(PODMAN) build -t $(REGISTRY)/$$img "$$project" || exit $$?; \
	done

build-nc: ## Build all project images as 'latest' without using the cache
	@for img in $(IMAGES); do \
		project="$$img"; \
		preparation_script="$$project/pre-make.sh"; \
		if [ -f "$$preparation_script" ]; then \
			echo "Using pre-make.sh script for preparation..."; \
			(cd "$$project" && bash ./pre-make.sh) || exit $$?; \
		fi; \
		$(PODMAN) build --no-cache -t $(REGISTRY)/$$img "$$project" || exit $$?; \
	done

tag: ## Tag all project images with their configured versions
	@for img in $(IMAGES); do \
		versionfile="$$img/VERSION"; \
		MY_APP_VERSION="$(VERSION)"; \
		if [ -f "$$versionfile" ]; then \
			MY_APP_VERSION=$$(cat "$$versionfile"); \
			echo "$(REGISTRY)/$$img version override: $$MY_APP_VERSION"; \
		fi; \
		$(PODMAN) tag $(REGISTRY)/$$img:latest $(REGISTRY)/$$img:$$MY_APP_VERSION || exit $$?; \
	done

versioning: ## Print all project versions
	@for img in $(IMAGES); do \
		versionfile="$$img/VERSION"; \
		MY_APP_VERSION="$(VERSION)"; \
		if [ -f "$$versionfile" ]; then MY_APP_VERSION=$$(cat "$$versionfile"); fi; \
		echo "$(REGISTRY)/$$img:$$MY_APP_VERSION"; \
	done

version: build tag ## Build and version all project images

release: build-nc publish ## Build and publish versioned and latest images

publish: publish-latest publish-version ## Publish the versioned and latest images

publish-latest: ## Push all latest project images
	@for img in $(IMAGES); do \
		$(PODMAN) push $(REGISTRY)/$$img:latest || exit $$?; \
	done

publish-version: tag ## Tag and push all project versions
	@for img in $(IMAGES); do \
		versionfile="$$img/VERSION"; \
		MY_APP_VERSION="$(VERSION)"; \
		if [ -f "$$versionfile" ]; then \
			MY_APP_VERSION=$$(cat "$$versionfile"); \
			echo "$(REGISTRY)/$$img version override: $$MY_APP_VERSION"; \
		fi; \
		$(PODMAN) push $(REGISTRY)/$$img:$$MY_APP_VERSION || exit $$?; \
	done

clean: rmc dangling ## Clean up project containers and dangling images
	@$(PODMAN) system prune -f; \
	$(PODMAN) images

cleaner: clean rmi ## Clean up and remove project images

cleanest: cleaner rmi-base-images ## Also remove base images

dangling: ## Remove dangling images
	@echo "Cleaning dangling images"; \
	$(PODMAN) image prune -f

rmi: rmi-version rmi-latest ## Remove all project images and versions

rmi-version: ## Remove local project images with their configured versions
	@echo "Removing all current versions for this project"; \
	for img in $(IMAGES); do \
		versionfile="$$img/VERSION"; \
		MY_APP_VERSION="$(VERSION)"; \
		if [ -f "$$versionfile" ]; then MY_APP_VERSION=$$(cat "$$versionfile"); fi; \
		$(PODMAN) rmi $(REGISTRY)/$$img:$$MY_APP_VERSION 2>/dev/null || true; \
	done

rmi-latest: ## Remove all local 'latest' project images
	@echo "Removing all images with version 'latest' from this project"; \
	for img in $(IMAGES); do \
		$(PODMAN) rmi $(REGISTRY)/$$img:latest 2>/dev/null || true; \
	done

rmi-base-images: ## Remove base images referenced by project Dockerfiles
	@echo "Removing all the base (FROM) images used in the projects"; \
	baseimgs=$$(find . -type f -name Dockerfile -exec grep -h '^[[:space:]]*FROM ' {} \; | sed 's/^[[:space:]]*FROM //; s/[[:space:]].*//'); \
	for base in $$baseimgs; do \
		case "$$base" in *:*) ;; *) echo "No version found; assuming latest"; base="$$base:latest" ;; esac; \
		if $(PODMAN) image exists "$$base"; then \
			echo "Removing base image: $$base"; \
			$(PODMAN) rmi "$$base" || exit $$?; \
		fi; \
	done

rmc: stop ## Stop and remove project containers
	@echo "Removing all created containers from this project"; \
	for cont in $$($(PODMAN) ps -aq); do \
		cname=$$($(PODMAN) container inspect --format '{{.Config.Image}}' "$$cont"); \
		for img in $(IMAGES); do \
			versionfile="$$img/VERSION"; \
			MY_APP_VERSION="$(VERSION)"; \
			if [ -f "$$versionfile" ]; then MY_APP_VERSION=$$(cat "$$versionfile"); fi; \
			if [ "$$cname" = "$(REGISTRY)/$$img" ] || [ "$$cname" = "$(REGISTRY)/$$img:$$MY_APP_VERSION" ]; then \
				echo "Removing container: $$cname -> $$cont"; \
				$(PODMAN) rm -f "$$cont" >/dev/null || exit $$?; \
				break; \
			fi; \
		done; \
	done

stop: ## Stop running containers based on project images
	@echo "Stopping all running containers from this project"; \
	for cont in $$($(PODMAN) ps -q); do \
		cname=$$($(PODMAN) container inspect --format '{{.Config.Image}}' "$$cont"); \
		for img in $(IMAGES); do \
			versionfile="$$img/VERSION"; \
			MY_APP_VERSION="$(VERSION)"; \
			if [ -f "$$versionfile" ]; then MY_APP_VERSION=$$(cat "$$versionfile"); fi; \
			if [ "$$cname" = "$(REGISTRY)/$$img" ] || [ "$$cname" = "$(REGISTRY)/$$img:$$MY_APP_VERSION" ]; then \
				echo "Stopping container: $$cname -> $$cont"; \
				$(PODMAN) stop "$$cont" >/dev/null || exit $$?; \
				break; \
			fi; \
		done; \
	done
