# Node.js

## What is Node.js?

> Node.js is a runtime environment built on V8 JavaScript engine. Its event-driven, non-blocking I/O model enables the development of fast, scalable, and data-intensive server applications.

[Overview of Node.js](http://nodejs.org/)

Trademarks: The respective trademarks mentioned in this document are owned by the respective companies, and use of them does not imply any affiliation or endorsement.

## Get this image

The recommended way to get the Node.js Docker Image is to pull the prebuilt image from the [AWS Public ECR Gallery](https://gallery.ecr.aws/bitcompat/node) or from the [GitHub Container Registry](https://github.com/bitcompat/node/pkgs/container/node).

```console
$ docker pull ghcr.io/bitcompat/node:latest
```

To use a specific version, you can pull a versioned tag. You can view the [list of available versions](https://github.com/bitcompat/node/pkgs/container/node/versions) in the GitHub Registry or the [available tags](https://gallery.ecr.aws/bitcompat/node) in the public ECR gallery.

```console
$ docker pull ghcr.io/bitcompat/node:[TAG]
```

## Entering the REPL

By default, running this image will drop you into the Node.js REPL, where you can interactively test and try things out in Node.js.

```console
$ docker run -it --name node ghcr.io/bitcompat/node
```

**Further Reading:**

- [nodejs.org/api/repl.html](https://nodejs.org/api/repl.html)

## Configuration

### Running your Node.js script

The default work directory for the Node.js image is `/app`. You can mount a folder from your host here that includes your Node.js script, and run it normally using the `node` command.

```console
$ docker run -it --name node -v /path/to/app:/app ghcr.io/bitcompat/node \
  node script.js
```

### Running a Node.js app with npm dependencies

If your Node.js app has a `package.json` defining your app's dependencies and start script, you can install the dependencies before running your app.

```console
$ docker run --rm -v /path/to/app:/app ghcr.io/bitcompat/node npm install
$ docker run -it --name node  -v /path/to/app:/app ghcr.io/bitcompat/node npm start
```

**Further Reading:**

- [package.json documentation](https://docs.npmjs.com/files/package.json)
- [npm start script](https://docs.npmjs.com/misc/scripts#default-values)

## Working with private npm modules

To work with npm private modules, it is necessary to be logged into npm. npm CLI uses *auth tokens* for authentication. Check the official [npm documentation](https://www.npmjs.com/package/get-npm-token) for further information about how to obtain the token.

If you are working in a Docker environment, you can inject the token at build time in your Dockerfile by using the ARG parameter as follows:

* Create a `npmrc` file within the project. It contains the instructions for the `npm` command to authenticate against npmjs.org registry. The `NPM_TOKEN` will be taken at build time. The file should look like this:

```console
//registry.npmjs.org/:_authToken=${NPM_TOKEN}
```

* Add some new lines to the Dockerfile in order to copy the `npmrc` file, add the expected `NPM_TOKEN` by using the ARG parameter, and remove the `npmrc` file once the npm install is completed.

You can find the Dockerfile below:

```dockerfile
FROM ghcr.io/bitcompat/node

ARG NPM_TOKEN
COPY npmrc /root/.npmrc

COPY . /app

WORKDIR /app
RUN npm install

CMD node app.js
```

* Now you can build the image using the above Dockerfile and the token. Run the `docker build` command as follows:

```console
$ docker build --build-arg NPM_TOKEN=${NPM_TOKEN} .
```

| NOTE: The "." at the end gives `docker build` the current directory as an argument.

Congratulations! You are now logged into the npm repo.

**Further reading**

- [npm official documentation](https://docs.npmjs.com/private-modules/docker-and-private-modules).

## Accessing a Node.js app running a web server

By default the image exposes the port `3000` of the container. You can use this port for your Node.js application server.

Below is an example of an [express.js](http://expressjs.com/) app listening to remote connections on port `3000`:

```javascript
var express = require('express');
var app = express();

app.get('/', function (req, res) {
  res.send('Hello World!');
});

var server = app.listen(3000, '0.0.0.0', function () {

  var host = server.address().address;
  var port = server.address().port;

  console.log('Example app listening at http://%s:%s', host, port);
});
```

To access your web server from your host machine you can ask Docker to map a random port on your host to port `3000` inside the container.

```console
$ docker run -it --name node -v /path/to/app:/app -P ghcr.io/bitcompat/node node index.js
```

Run `docker port` to determine the random port Docker assigned.

```console
$ docker port node
3000/tcp -> 0.0.0.0:32769
```

You can also specify the port you want forwarded from your host to the container.

```console
$ docker run -it --name node -p 8080:3000 -v /path/to/app:/app ghcr.io/bitcompat/node node index.js
```

Access your web server in the browser by navigating to `http://localhost:8080`.

## Connecting to other containers

If you want to connect to your Node.js web server inside another container, you can use docker networking to create a network and attach all the containers to that network.

### Serving your Node.js app through an nginx frontend

We may want to make our Node.js web server only accessible via an nginx web server. Doing so will allow us to setup more complex configuration, serve static assets using nginx, load balance to different Node.js instances, etc.

#### Step 1: Create a network

```console
$ docker network create app-tier --driver bridge
```

#### Step 2: Create a virtual host

Let's create an nginx virtual host to reverse proxy to our Node.js container.

```nginx
server {
    listen 0.0.0.0:80;
    server_name yourapp.com;

    location / {
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header HOST $http_host;
        proxy_set_header X-NginX-Proxy true;

        # proxy_pass http://[your_node_container_link_alias]:3000;
        proxy_pass http://myapp:3000;
        proxy_redirect off;
    }
}
```

Notice we've substituted the link alias name `myapp`, we will use the same name when creating the container.

Copy the virtual host above, saving the file somewhere on your host. We will mount it as a volume in our nginx container.

#### Step 3: Run the Node.js image with a specific name

```console
$ docker run -it --name myapp --network app-tier \
  -v /path/to/app:/app \
  ghcr.io/bitcompat/node node index.js
```

#### Step 4: Run the nginx image

```console
$ docker run -it \
  -v /path/to/vhost.conf:/bitnami/nginx/conf/vhosts/yourapp.conf:ro \
  --network app-tier \
  ghcr.io/bitcompat/nginx
```

## Maintenance

### Upgrade this image

Up-to-date versions of Node.js, including security patches, soon after they are made upstream. We recommend that you follow these steps to upgrade your container.

#### Step 1: Get the updated image

```console
$ docker pull ghcr.io/bitcompat/node:latest
```

or if you're using Docker Compose, update the value of the image property to `ghcr.io/bitcompat/node:latest`.

#### Step 2: Remove the currently running container

```console
$ docker rm -v node
```

or using Docker Compose:

```console
$ docker-compose rm -v node
```

#### Step 3: Run the new image

Re-create your container from the new image.

```console
$ docker run --name node ghcr.io/bitcompat/node:latest
```

or using Docker Compose:

```console
$ docker-compose up node
```

## Contributing

We'd love for you to contribute to this container. You can request new features by creating an [issue](https://github.com/bitcompat/node/issues), or submit a [pull request](https://github.com/bitcompat/node/pulls) with your contribution.

## Issues

If you encountered a problem running this container, you can file an [issue](https://github.com/bitcompat/node/issues/new).

## License

This package is released under MIT license.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
