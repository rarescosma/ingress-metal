ingress-metal
-------------
ingress-metal is an experiment aimed at converting the official
[ingress-nginx](https://kubernetes.github.io/ingress-nginx/) docker image
into a zero-dependency `.deb` package, runnable on bare metal hosts or VMs.

### Usage

The build script has several dependencies: `openssl`, `dpkg-deb` and `docker`:
- `dpkg-deb` is present on most APT-based distros
- `openssl` can be installed with `apt-get install openssl`
- consult the docker documentation on how to install docker, 
  or use [podman](https://podman.io/) as an excellent alternative

Simply:

    ./build.sh

Or, to use `podman` instead of `docker`:

    DOCKER=podman ./build.sh 

Or, to pull a specific image, perhaps from a different registry:

    IMAGE=hub.getbetter.ro/ingress-nginx:v1.5.1 ./build.sh

### But why?

But why not?

The main scenario is to simplify the ingress setup for a virtualized
Kubernetes setup: one metal server hosts several worker node VMs and we need to
route HTTP(s) traffic to the pods.

Normally we'd have `ingress-nginx` deployed as a DaemonSet with proxy
protocol turned on + another layer of nginx running on the metal host proxying
requests to the inner nginx.

By using `ingress-metal` we eliminate the proxying so traffic flows from the public network, through 
the `ingress-metal` nginx running on metal, then directly to the pods.

### Operation

Have a look at the [run script](bin/run.sh) for an idea on how to operate.

By default it will look for an ingress config map named `ingress-metal` in 
the `ingress-system` namespace.

The [run script](bin/run.sh) also expects the path to a `KUBECONFIG` file as
its first argument. This can be [extracted](https://stackoverflow.com/questions/47770676/how-to-create-a-kubectl-config-file-for-serviceaccount) 
from the service account associated with the existing (inner) 
nginx-ingress stack.
