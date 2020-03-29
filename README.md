# Docker Makefile project

This project provides a convention over configuration
universal build `Makefile` for [docker](https://www.docker.com/) projects.

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
# make all projects
make build 
# make single project
make hello-world
```

## VERSION

if you put a `VERSION` file in a folder with a `Dockerfile` and put only a version in it it will override the
default version as described in the `makefile.env`


## build.sh

if you put a `build.sh` script in the folder with a `Dockerfile` that is the script used by make otherwise it will 
us a default build command.
