# django_learn
This project serves as a demonstrator for full chain CI/CD, using GitHub Actions and Kubernetes.
It is a self-contained project that has everything for A-Z CI/CD deployments against Kubernetes.

See [Environments](https://github.com/jslay88/django_learn/deployments/activity_log?environment=production)
for deployments.

It is intended to be used to understand the following: 
* Containerizing Django with Gunicorn
* Docker Best Practices
  * Security
  * Multi-stage
  * Leverages docker/dockerfile Build Kit image (ln#1 Dockerfile) for newer features
    * Uses new heredoc feature
* Helm Best Practices
  * Leverages child chart helper templates
  * Can disable child charts and still provide external topology/credentials
  * Uses file mounts for secrets for better security
* GitHub Actions
  * Builds Docker Image
    * `lastest` with merge to `master`, `*.*.*` with `v*.*.*` release.
  * Pushes Docker Image to GHCR
  * Automates cutting a release on `v*.*.*` tag push
  * Deploys to Kubernetes via Helm when a new release is cut
    * Leverages GitHub Environments

## TODO
I would eventually like to cookie-cutter this project, and support multiple application frameworks
(Django, Flask, FastAPI, etc).


## Try it out
Make some changes to the Django application (say, update `templates/home/index.html`). Push to a PR and merge to
`master`, or just push to `master`. This will kick off `docker.yml` for the `latest` tag.

Create a new release by making a new git tag from master with `v*.*.*` pattern, and push it.

    git tag v0.1.2 master
    git push -u origin v0.1.2

Go to the `Actions` tab [here](https://github.com/jslay88/django_learn/actions) and watch the `release.yml`
workflow execute.

View your changes at https://django-learn.k8s.jslay.net/


## Docker
This image leverages a newer Dockerfile build image, and it requires Build Kit to be enabled `BUILD_KIT=1`.
This enables the use of heredoc, as well as other new features. See [here](https://hub.docker.com/r/docker/dockerfile)
for more information. Further improvements could be added, such as using the `--mount` option to mount in 
a cache directory of Python dependencies between image builds to speed up image building. 

The image has been designed to have a dev layer that is empty of code (requires code volume mounts), for use
with docker-compose. The prod layer contains all code and dependencies.

The image also supports reading secrets from `/var/run/secrets/django_learn`. File name should match the 
variable name, and the contents of the file should be the value of the secret. Secrets will be available
in their respective folders (`django`, `postgres`, `twitch`).

## Kubernetes
This chart packages [Bitnami's `postgresql` Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql).
By default, the `postgresql` chart is disabled. You can enable it with `postgresql.enabled=true`. 
Currently, this is deployed automatically against my Kubernetes cluster in my home lab. 

The `deploy.yml` workflow also depends on a self-hosted runner with the ability to deploy to the cluster.
It is recommended to set up ARC in your cluster, create a namespace for this project, and deploy a runner 
to the namespace. More information on ARC can be found 
[here](https://github.com/actions-runner-controller/actions-runner-controller).

Example Runner:
```YAML
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: github-runner
  namespace: django-learn
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: github-runner
  namespace: django-learn
subjects:
  - kind: ServiceAccount
    name: github-runner
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: github-runner
  namespace: django-learn
spec:
  replicas: 1
  template:
    spec:
      repository: jslay88/django_learn
      serviceAccountName: github-runner
```

## GitHub Actions
There are 3 workflow files (`docker.yml`, `deploy.yml`, and `release.yml`).

### `docker.yml`
This workflow builds and pushes docker images to GHCR. It is also possible to call this workflow from
within another workflow. By default, it will only trigger itself on merge to master, and push the `latest` tag.

### `deploy.yml`
This workflow performs the `helm upgrade --install` for the Helm chart. It designed to call this workflow
from within another workflow. It has 2 input parameters, environment name, and url. Environment name 
corresponds to the GitHub Environment for which the deployment is targeting. This workflow is usually 
called by `release.yml`.

### `release.yml`
This workflow is triggered by pushing a tag matching `v*.*.*` pattern. This workflow ties together `docker.yml` 
and `deploy.yml`. When it calls `deploy.yml`, it will build and push the `*.*.*` tag (no `v`) for the release.
It will also cut a new release for the tag. Once the `docker.yml` workflow completes successfully, it then 
calls `deploy.yml`.
