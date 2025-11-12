In this section, we will run a straightforward web application with Docker over HTTP. There are two ways you can reach a service over the network:

- by directly accessing the server's IP address and optionally the port the service is running on, e.g., `http://192.168.178.5:8080`
- by accessing a hostname or domain name that gets resolved to the IP of the server the service is running on, and optionally the port the service is running on, e.g., `http://homeserver.local:8080`

For this step, we will focus on the first access method. In the next step, we will set up a DNS server and custom records to access the service via its DNS name.

In the previous chapter, we introduced Docker and gave some examples of how to run a container. For this section, we will use [draw.io](https://www.drawio.com/) as an example.

In `containers/drawio/` you will find the compose file:

```yaml
services:
  drawio:
    image: jgraph/drawio
    container_name: drawio
    restart: unless-stopped
    ports:
 - 8080:8080
```

In the compose file, we specify the service `drawio`. We use the `jgraph/drawio` image and expose the container's port `8080` on the host's port `8080`. To start the stack, run `sudo docker compose up -d`.

Given the IP address of your server, you should now be able to visit the service at `http://<server ip>:8080`.