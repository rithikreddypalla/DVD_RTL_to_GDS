#!/bin/bash
# Resource gate: run BEFORE `docker pull` and before each LibreLane run.
# Exit code 0 = safe to proceed, 1 = not enough resources.
NEED_DISK_GB=20     # IIC-OSIC-TOOLS README: "at least 20 GB of free drive space"
NEED_MEM_GB=3       # available RAM + free swap for a LibreLane run (assignment asks Docker for 8 GB total)
fail=0

root=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo /var/lib/docker)
disk_gb=$(df -BG --output=avail "$root" 2>/dev/null | tail -1 | tr -dc '0-9')
mem_gb=$(awk '/MemAvailable/{printf "%d", $2/1048576}' /proc/meminfo)
swap_gb=$(awk '/SwapFree/{printf "%d", $2/1048576}' /proc/meminfo)

echo "Docker root : $root"
echo "Free disk   : ${disk_gb:-?} GB   (need >= ${NEED_DISK_GB})"
echo "Avail RAM   : ${mem_gb} GB + ${swap_gb} GB free swap   (need >= ${NEED_MEM_GB} total)"
echo "CPUs        : $(nproc)   (assignment suggests >= 4)"

[ "${disk_gb:-0}" -ge "$NEED_DISK_GB" ] || { echo "FAIL: not enough disk for the image (free space first, see plan.md section 3)"; fail=1; }
[ $((mem_gb + swap_gb)) -ge "$NEED_MEM_GB" ] || { echo "FAIL: not enough memory (close browser/IDE windows)"; fail=1; }
[ $fail -eq 0 ] && echo "OK: resources sufficient"
exit $fail
