# Docker Makefile project

This project provides a convention-over-configuration build `Makefile` for
[Podman](https://podman.io/) projects. It builds from standard `Dockerfile`s
using the Podman command-line interface.

## Blog

This [blog](http://ivo2u.nl/oE) post tells all about it.

## install

```bash
brew tap ivonet/cli
brew install docker-make
```

## Convention

if you use this convention everything should work just fine:

```text
.
├── Makefile
├── makefile.env
├── README.md
├── hello-world
│   └── Dockerfile
├── ngnix
│   └── Dockerfile
├── node
│   ├── Dockerfile
│   ├── VERSION
│   └── src
│       ├── index.js
│       ├── index.html
│       └── angular.js
└── payara
    └── Dockerfile
    
```
## Usage

example usage:

```bash
mkdir -p example-project/hello-world
cd example-project
echo "FROM busybox\nCMD [\"echo\", \"Hello, world!\"]" >hello-world/Dockerfile
echo "VERSION=1.0\nREGISTRY=$USER">makefile.env
docker-make
# Show help
make help
# make all projects with Podman
make build 
# make single project
make hello-world
```

## VERSION

if you put a `VERSION` file in a folder with a `Dockerfile` and put only a version in it, it will override the
default version as described in the `makefile.env`


## pre-make.sh

if you put a `pre-make.sh` script in the folder with a `Dockerfile`, make runs
that script before running a Podman build.

## Podman

Install and configure Podman before using the Makefile. The `multi-<project>`
target builds and pushes a multi-platform manifest for `linux/amd64` and
`linux/arm64/v8`; it does not require Docker Buildx or a separate builder.
