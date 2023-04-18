# drone-runner
A configurable drone runner that uses the Exec runner for ci and cd, depending on config

https://github.com/drone-runners/
https://github.com/harness/harness-docker-runner

## Notes

- Should be based on the podman-container
- Movingto [podman-compose](https://github.com/containers/podman-compose)
- Need to add labels to the compose file.
- Remove Containers `/usr/bin/podman rm $(/usr/bin/podman ps -aq)`
- Remove Volumes `/usr/bin/podman volume rm $(/usr/bin/podman volume list -q)`
