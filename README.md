# docker-buildroot

Shared Docker infrastructure for running [Buildroot][buildroot] builds in an
isolated, reproducible environment — independent of the host OS (macOS or
Linux).

It is designed to support multiple independent
[BR2_EXTERNAL][br2_external] trees simultaneously, each with its own
defconfigs, outputs, and run scripts, while sharing a common Buildroot source,
download cache, and CCache.


## Architecture

```
docker-buildroot/              ← this repo (shared infrastructure)
  Dockerfile                   ← Ubuntu 24.04 build environment
  BUILDROOT_VERSION            ← Buildroot fork and branch (source of truth)
  buildroot/                   ← Buildroot source (cloned via bootstrap.sh, bind-mounted)
  scripts/
    bootstrap.sh               ← clones/updates buildroot/ from BUILDROOT_VERSION
    colima.sh                  ← manages Colima VM on external SSD (macOS)
    run_template.sh            ← template for new BR2_EXTERNAL run scripts
  externals/
    my_project/                ← a BR2_EXTERNAL repo (cloned here)
      run_my_target.sh         ← calls docker from the root of this repo
    another_project/           ← another BR2_EXTERNAL repo
  _locals/                     ← secrets and local config (gitignored, not committed)
  images/  target/  graphs/   ← build outputs, organized by project/target
```

The Docker named volume `buildroot_workspace` holds all intermediate build
artifacts (object files, CCache, downloads). It lives inside the Docker VM,
keeping heavy I/O off the host filesystem.


## Quick Setup

> **macOS users:** if you plan to use an external SSD with Colima, complete the
> [macOS setup](#macos-notes) before step 2 — the VM must be running before any `docker` command.

### 1. Clone this repo and dependencies

```shell
git clone https://github.com/vidalastudillo/docker-buildroot
cd docker-buildroot
./scripts/bootstrap.sh
git clone https://github.com/<user>/<my_project> ./externals/my_project
```

See [Buildroot source](#buildroot-source-buildroot_version) for details and the manual alternative.

### 2. Build the Docker image

```shell
docker buildx build -t va_buildroot .
```

The image name defaults to `va_buildroot` across all run scripts. To use a
different name, set the environment variable before running any script:

```shell
export BUILDROOT_IMAGE=my_custom_image
docker buildx build -t "$BUILDROOT_IMAGE" .
```

### 3. Create the shared workspace volume

```shell
docker volume create buildroot_workspace
```

This volume is shared across all externals. It holds:

| Path inside volume | Contents |
|--------------------|----------|
| `/workspace/dl` | Downloaded source archives (shared) |
| `/workspace/ccache` | Compiler cache (shared) |
| `/workspace/outputs/<project>/<target>` | Per-target build tree |


## Usage

Each BR2_EXTERNAL provides its own run script(s). They must be called from
the root of this repo:

```shell
./externals/my_project/run_my_target.sh make my_defconfig
./externals/my_project/run_my_target.sh make menuconfig
./externals/my_project/run_my_target.sh make all
```

Build outputs (`images/`, `target/`, `graphs/`) are bind-mounted to the host
under the corresponding subdirectory.

For an interactive shell inside the container:

```shell
./externals/my_project/run_my_target.sh
```


## Creating a new BR2_EXTERNAL run script

Copy the provided template and fill in the configuration section:

```shell
cp scripts/run_template.sh externals/my_project/run_my_target.sh
chmod +x externals/my_project/run_my_target.sh
```

Edit the variables at the top of the script:

| Variable | Description |
|----------|-------------|
| `OUTPUT_NAME` | Subdirectory for outputs, e.g. `pi_swupdate/cm4` |
| `MY_EXTERNAL` | Path to the external tree inside the container |
| `CCACHE_LIMIT` | Maximum CCache size |

The `BUILDROOT_IMAGE` variable is read from the environment, defaulting to
`va_buildroot`.


## Buildroot source (`BUILDROOT_VERSION`)

The Buildroot fork and branch used by this project are defined in `BUILDROOT_VERSION`:

```
BUILDROOT_REPO=https://github.com/vidalastudillo/buildroot.git
BUILDROOT_BRANCH=2025.11.x
```

`scripts/bootstrap.sh` reads this file and clones or updates `buildroot/` to
the tip of the configured branch. Using the script is recommended: any
BR2_EXTERNAL or CI pipeline that calls it stays automatically in sync when
`BUILDROOT_VERSION` changes — no manual updates needed across repositories.

The script is optional. To clone manually using the values in `BUILDROOT_VERSION`:

```shell
source BUILDROOT_VERSION && git clone --branch "$BUILDROOT_BRANCH" "$BUILDROOT_REPO" ./buildroot
```

To use a different Buildroot fork or branch, edit `BUILDROOT_VERSION` before
running the script.


## Local secrets (`_locals/`)

Sensitive files (API tokens, keys, certificates) that individual BR2_EXTERNAL
trees need at build time are placed under `_locals/` and mounted into the
container as Docker secrets. This directory is gitignored and must be created
manually on each machine.

Each external defines its own namespace inside `_locals/`. Refer to the
run script and documentation of that external for the exact layout required.


## macOS notes

On macOS with Colima, use the provided `scripts/colima.sh` to host
the Docker VM on an external SSD. This prevents internal SSD wear from the
heavy I/O generated by Buildroot builds.

Docker Desktop does not preserve its VM image path when configured to use an
external volume, so its data always lands on the internal SSD regardless of
configuration. Colima solves this by symlinking `~/.colima` to the external
SSD before the VM is created.

```shell
./scripts/colima.sh setup   # once — creates the VM on the external SSD
./scripts/colima.sh up      # daily startup
```

The SSD name defaults to `Container Image`. Override via environment variable
for persistent configuration (e.g., add to `~/.zprofile`):

```shell
export COLIMA_SSD_NAME="My SSD"   # default: "Container Image"
export COLIMA_CPUS=4               # default: 4
export COLIMA_MEMORY=10            # default: 10 (GiB)
export COLIMA_DISK=800             # default: 800 (GiB)
```


## License

Mozilla Public License 2.0.

Based on original work &copy; 2017 Auke Willem Oosterhoff /
[Advanced Climate Systems][acs].  
&copy; 2022-2026 [VIDAL & ASTUDILLO Ltda][va]. All rights reserved.

[va]: https://www.vidalastudillo.com
[acs]: http://advancedclimate.nl
[buildroot]: https://buildroot.org/
[br2_external]: https://buildroot.org/downloads/manual/manual.html#outside-br-custom
