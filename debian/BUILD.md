# Building Ollama Debian packages

## Packages

```text
ollama                         # CPU + server + systemd
  Suggests: ollama-cuda        # virtual

ollama-cuda-13  Provides: ollama-cuda
  Depends: ollama (= same version)
```

| Package | Ships |
|---------|--------|
| `ollama` | binary, CPU libs, systemd unit |
| `ollama-cuda-13` | `/usr/lib/ollama/cuda_v13/` (Depends: NVIDIA `cuda-cudart-13-*`, `libcublas-13-*`) |

CUDA runtime Depends use packages from
https://developer.download.nvidia.com/compute/cuda/repos/ (cuda-keyring)

## Build dependencies

From `control`: debhelper, cmake, ninja, Go >= 1.26, gcc/g++, git, ca-certificates.

CUDA toolkits are not Build-Depends:

| Goal | Build-time need |
|------|-----------------|
| CPU only | no NVIDIA toolkit |
| `ollama-cuda-13` | NVIDIA `cuda-nvcc-13-*` + `libcublas-dev-13-*` |

On Debian with cuda-keyring
```
sudo apt install cuda-nvcc-13-3 libcublas-dev-13-3
# gets installed into /usr/local/cuda/bin/nvcc
```

CUDA 13.x `nvcc` only accepts host GCC ≤ 15. On hosts whose default `gcc` is
newer (Debian unstable often ships 16), install a supported side-by-side
compiler; `debian/rules` picks it automatically:

```
sudo apt install g++-15
# or: g++-14
# override: CMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-15
```

Also needs network (Go modules + pinned llama.cpp).

## Build

```sh
debian/build.sh
```

Writes `debian/changelog` from git, then `dpkg-buildpackage -b`.

| Git | Version |
|-----|---------|
| On latest tag `vX.Y.Z`, clean tree | `X.Y.Z-1` |
| Other commit, clean tree | `X.Y.Z+<12-char hash>-1` |
| Uncommitted changes | `X.Y.Z+dirty-1` |

```sh
# CPU only (no nvcc required)
OLLAMA_CUDA_BACKENDS= debian/build.sh

# CUDA 13 only
OLLAMA_CUDA_BACKENDS=cuda_v13 debian/build.sh

# This machine only: -march=native -O3 -flto, CUDA for local GPUs, OpenMP, IPO
debian/build-native.sh
```

`build-native.sh` sets `OLLAMA_CUDA_ARCHITECTURES` from every GPU reported by
`nvidia-smi` (e.g. `120;75` for a 5060 Ti + 1660 SUPER). Override if needed:

```sh
OLLAMA_CUDA_ARCHITECTURES=75;120 debian/build-native.sh
```

Rebuild after adding a GPU — binaries only include arches present (or overridden)
at build time.

Outputs land in `debian/`.

By default `dpkg-buildpackage` runs `clean` first (wipes `build/`). For faster rebuilds skip that:

```sh
debian/build.sh -nc
```

Go module / build caches use your normal user dirs (`~/go/pkg/mod`,
`~/.cache/go-build`). `debian/rules` sets `GOMODCACHE` / `GOCACHE` explicitly
because debhelper compat 13+ points `HOME` at a throwaway directory under
`debian/.debhelper/` that is deleted on every clean.

Warm the module cache once (optional):

```sh
go mod download
```

## Install

NVIDIA CUDA repo (once):

```sh
# https://developer.nvidia.com/cuda-downloads - cuda-keyring for your distro
sudo dpkg -i cuda-keyring_*.deb && sudo apt update
```

```sh
sudo apt install ./debian/ollama_*.deb ./debian/ollama-cuda-13_*.deb
sudo systemctl enable --now ollama
```
