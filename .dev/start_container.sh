#!/bin/bash
# Launch the IIC-OSIC-TOOLS container with THIS repository as the designs folder.
#
# Upstream default: host ~/eda/designs  ->  container /foss/designs
# Here:             host <repo root>    ->  container /foss/designs
# (the repo root is the parent of this .dev/ folder, so it works wherever the repo is cloned)
#
# Usage:
#   .dev/start_container.sh            # interactive shell (default)
#   .dev/start_container.sh vnc        # desktop in browser: http://localhost:8080  (VNC pw: abc123)
#   .dev/start_container.sh gui        # shell with host X11 forwarded (gtkwave/klayout open on host screen)
#   .dev/start_container.sh stop       # stop the vnc container
#
# Overrides (env): IIC_TAG, WEBSERVER_PORT, VNC_PORT
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESIGNS="${DESIGNS:-$REPO_ROOT}"                 # <- the path the container treats as its parent folder
IMAGE="hpretl/iic-osic-tools:${IIC_TAG:-2026.10}" # pinned tag, not "latest", for reproducible results
NAME="iic-osic-tools_vlsi_assignment"
WEBSERVER_PORT="${WEBSERVER_PORT:-8080}"
VNC_PORT="${VNC_PORT:-5901}"

# Run as the host user so files written to /foss/designs are NOT root-owned on the host.
USER_OPTS=(--user "$(id -u):$(id -g)")
COMMON=(--security-opt seccomp=unconfined -v "${DESIGNS}:/foss/designs:rw")

case "${1:-shell}" in
  shell)
    exec docker run -it --rm --name "$NAME" "${USER_OPTS[@]}" "${COMMON[@]}" "$IMAGE" -s /bin/bash
    ;;
  gui)
    xhost +local:docker >/dev/null
    exec docker run -it --rm --name "$NAME" "${USER_OPTS[@]}" "${COMMON[@]}" \
      -e DISPLAY="${DISPLAY:-:0}" -v /tmp/.X11-unix:/tmp/.X11-unix "$IMAGE" -s /bin/bash
    ;;
  vnc)
    docker run -d --rm --name "$NAME" "${USER_OPTS[@]}" "${COMMON[@]}" \
      -p "${WEBSERVER_PORT}:80" -p "${VNC_PORT}:5901" "$IMAGE"
    echo "Open http://localhost:${WEBSERVER_PORT}  (VNC password: abc123). Stop with: $0 stop"
    ;;
  stop)
    docker stop "$NAME"
    ;;
  *)
    sed -n '2,14p' "$0"; exit 1
    ;;
esac
