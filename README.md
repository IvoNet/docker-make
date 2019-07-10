# Docker Makefile project

This project provides a convention over configuration
universal build `Makefile`

## Blog

This blog post tells all about it.

## Usage

```bash
mkdir -p example-project/hello-world
cd example-project
echo "FROM busybox\nCMD [\"echo\", \"Hello, world!\"]" >hello-world/Dockerfile
echo "VERSION=1.0\nREGISTRY=$USER">makefile.env
wget https://raw.githubusercontent.com/IvoNet/docker-make/master/Makefile
# Show help
make help
# make all projects
make build 
# make single project
make hello-world
```

## Convention

if you use this convention everything should work just fine:

``text
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
│   └── src
│       ├── index.js
│       ├── index.html
│       └── angular.js
└── payara
    └── Dockerfile
```



