# drone-runner
A configurable drone runner that uses the **exec** runner for ci builds

https://github.com/drone-runners/
https://github.com/harness/harness-docker-runner

## Development

Environment variables must be set for the runner to function properly.  These should be set as environment variables in the **deployment.yml** manifest.

```
DRONE_RUNNER_NAME=drone-runner-ci
DRONE_RPC_PROTO=http
DRONE_RPC_HOST=<FQDN>
DRONE_RPC_SECRET=<DRONE SERVER TOKEN>
DRONE_DEBUG=true
```

## Notes
- 2024-03-02: Reworked the container to work with new builds.
- Should be based on the podman-container
- Movingto [podman-compose](https://github.com/containers/podman-compose)
- Need to add labels to the compose file.
- Remove Containers `/usr/bin/podman rm $(/usr/bin/podman ps -aq)`
- Remove Volumes `/usr/bin/podman volume rm $(/usr/bin/podman volume list -q)`
