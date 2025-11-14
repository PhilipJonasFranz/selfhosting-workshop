# 3 - Docker

A container is a lightweight, isolated environment that shares the host's operating system kernel. Containers are a form of virtualization, specifically OS-level virtualization. It starts up much faster than a VM and has a much lower overhead.

To run a container, an image is required. The image packages the application and all of its dependencies. Using containers to deploy has various benefits:

- Dependency management is simplified; the image contains everything needed to run the service
- containers are isolated, increasing security
- Host access can be given selectively, like file-system access
- removing a container removes all related files and dependencies, ensuring the system stays clean
- because everything uses the same interface, managing applications at scale is simplified

However, using containers also has some drawbacks. Because everything is packaged into the container image, it can take longer for security patches to be integrated into container images, as the maintainer has to rebuild the container to include the most up-to-date library versions.

[Docker](https://www.docker.com/) is a containerization engine that introduces a tooling ecosystem around the generic concept of containerization. It provides tools to build, run, and distribute container images. There are other container engines, like [podman](https://podman.io/).

# Docker Installation

To install Docker, run:

```bash
curl -fsSL https://get.docker.com | sudo bash
```

⚠️ **Important**: There is a breaking change with Docker version 29, which increases the minimum required API version, which breaks downstream projects such as Traefik. Until a fix is available, as a temporary measurement, downgrade Docker to version 28:

Ubuntu 22.04:

```bash
sudo apt-get install docker-ce=5:28.5.2-1~ubuntu.22.04~jammy docker-ce-cli=5:28.5.2-1~ubuntu.22.04~jammy containerd.io docker-buildx-plugin docker-compose-plugin
```

Ubuntu 24.04:

```bash
sudo apt-get install docker-ce=5:28.5.2-1~ubuntu.24.04~noble docker-ce-cli=5:28.5.2-1~ubuntu.24.04~noble containerd.io docker-buildx-plugin docker-compose-plugin
```

# Docker Images

A Docker image is a stack of read-only layers, plus metadata, that describes how to run the container. Each layer is a filesystem that adds files to the image. Each layer is immutable. The base layer is a minimal OS userspace, e.g., `alpine` or `ubuntu`, but not a full OS or kernel.

To create a Docker image, a `Dockerfile` is used, for example, from [Docker Docs](https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile/):

```Dockerfile
FROM nginx:alpine

# Copy custom HTML
COPY index.html /usr/share/nginx/html/index.html

# Expose port (documentation only)
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
```

This Dockerfile starts with an Alpine-based nginx base layer. Alpine is a minimal Linux distribution often used to build small and lightweight images. Afterwards, the `index.html` file is copied to the path `/usr/share/nginx/html/index.html` on the image. Finally, the `CMD` specifies how to start the container image.

The resulting image contains all dependencies to run nginx, as well as the website itself. To build the Docker image, run `docker build -t my-image .`, where `.` refers to the location of the `Dockerfile`. Docker tags images to add name and versioning information. In this case, the image's name is `my-image`. To further add a version tag, run `docker tag my-image:1.0.0 my-image:latest` to add the versions `1.0.0` and `latest`.

# Running a Docker Container

To run a Docker container, use the `docker run` command:

```bash
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

Arguments:
- `IMAGE`: the Docker image to run.
- `COMMAND`: optional override for the image's default command.
- `OPTIONS`: configure runtime behavior (ports, volumes, environment variables, etc.).

Example:

```bash
docker run -d -p 8080:80 --name webserver my-image:latest
```

Common Options:
- `-d`: run container in detached (background) mode.
- `--name NAME`: assign a custom name to the container.

- `-v HOST:CONTAINER`: mount host directory as a volume.

## Publishing Ports

To make the application running inside the Docker container accessible from the outside, a port has to be published on which the application responds to requests. For example, the Webserver Nginx typically listens on port `80`. To publish this port to the host, use the `-p` option in the `docker run` command. For example, to map the host port `8080` to the container port `80`, use `-p 8080:80`:

```bash
docker run -p 8080:80 --name webserver my-image:latest
```

## Environment Variables

Environment variables can be read by a container as a mechanism to pass configuration values or secrets. They can be set as part of the container run configuration:

```bash
docker run -e NGINX_HOST=localhost --name webserver my-image:latest
```

## Volume Mounts

To ensure the persistence of data for stateful workloads, such as databases, containers require access to a file system. This can be achieved in two ways: using Docker volumes and bind mounts:

- Volumes are entirely managed by Docker, and are designed to be used with Docker containers
- Bind Mounts give containers access to the host file system

To attach a volume to a Docker container, use the `-v` or `--volume` flag:

```bash
# For Docker volume
docker run --name postgres -v pgdata:/var/lib/postgresql/data -p 5432:5432 postgres:latest

# For bind mount
docker run --name postgres -v ./postgres-data:/var/lib/postgresql/data -p 5433:5432 postgres:latest
```

The syntax for mounting a Docker volume and a bind mount differs only in that the former uses a volume name, while the latter uses a relative or absolute file path on the host file system. Both mount to a filepath inside the container, where it can read and (if allowed) write data to.

# Docker Compose

Compose is a utility for running and managing multi-container application stacks. Stacks are defined in configuration files called `docker-compose.yml`. Docker Compose also has some capabilities that are hard, if not impossible, to achieve with generic Docker CLI commands. For more information, visit the [Docker Compose Docs](https://docs.docker.com/compose/).