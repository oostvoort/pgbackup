REPO = oostvoort
IMAGE = pgbackup

all:: build-14 build-15


build-14:
	docker build \
		--rm \
		--build-arg POSTGRES_VERSION=14 \
		--tag=$(REPO)/$(IMAGE):14-latest \
		.

	docker push $(REPO)/$(IMAGE):14-latest

build-15:
	docker build \
		--rm \
		--build-arg POSTGRES_VERSION=15 \
		--tag=$(REPO)/$(IMAGE):15-latest \
		.

	docker push $(REPO)/$(IMAGE):15-latest



shell:
	docker run --interactive --rm --tty $(REPO):$(TAG) /bin/bash
