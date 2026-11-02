#!/bin/sh
# Build Ollama .debs tuned for this machine only (not portable).
# No GGML_NATIVE (incompatible with GGML_BACKEND_DL).
set -eu
cd "$(dirname "$0")/.."

# Host C/C++: this CPU, stronger opts, LTO
_native_c='-march=native -mtune=native -O3 -flto=auto'
export DEB_CFLAGS_APPEND="${DEB_CFLAGS_APPEND:+$DEB_CFLAGS_APPEND }${_native_c}"
export DEB_CXXFLAGS_APPEND="${DEB_CXXFLAGS_APPEND:+$DEB_CXXFLAGS_APPEND }${_native_c}"
export DEB_FFLAGS_APPEND="${DEB_FFLAGS_APPEND:+$DEB_FFLAGS_APPEND }${_native_c}"
export DEB_FCFLAGS_APPEND="${DEB_FCFLAGS_APPEND:+$DEB_FCFLAGS_APPEND }${_native_c}"
export DEB_LDFLAGS_APPEND="${DEB_LDFLAGS_APPEND:+$DEB_LDFLAGS_APPEND }-flto=auto"

export CGO_CFLAGS="${CGO_CFLAGS:-$(dpkg-buildflags --get CFLAGS)}"
export CGO_CXXFLAGS="${CGO_CXXFLAGS:-$(dpkg-buildflags --get CXXFLAGS)}"
export CGO_LDFLAGS="${CGO_LDFLAGS:-$(dpkg-buildflags --get LDFLAGS)}"

# GPU: this machine only. Prefer explicit arches from every visible NVIDIA
# GPU (nvidia-smi). CMAKE "native" only sees GPUs present at configure time —
# if you add a card later you must rebuild, and listing arches makes that clear.
detect_cuda_architectures() {
	if ! command -v nvidia-smi >/dev/null 2>&1; then
		echo "native"
		return
	fi
	# csv: "7.5" / "12.0" -> CMAKE form 75 / 120; unique, stable order
	_arches=$(
		nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null \
			| tr -d ' ' \
			| awk -F. 'NF>=2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
				a = $1 $2
				if (!seen[a]++) {
					out = (out ? out ";" : "") a
				}
			}
			END { print out }'
	)
	if [ -n "$_arches" ]; then
		echo "$_arches"
	else
		echo "native"
	fi
}

if [ -z "${OLLAMA_CUDA_ARCHITECTURES:-}" ]; then
	OLLAMA_CUDA_ARCHITECTURES=$(detect_cuda_architectures)
fi
export OLLAMA_CUDA_ARCHITECTURES
export OLLAMA_CUDA_BACKENDS="${OLLAMA_CUDA_BACKENDS:-cuda_v13}"

# CMake extras (passed via debian/rules CMAKE_EXTRA). OpenMP + LTO only;
# keep default multi-variant CPU backends (required with GGML_BACKEND_DL).
export OLLAMA_CMAKE_EXTRA="${OLLAMA_CMAKE_EXTRA:+$OLLAMA_CMAKE_EXTRA }-DGGML_OPENMP=ON -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON"

# Version / .deb names get +native
export OLLAMA_DEB_NATIVE=1

# NVIDIA toolkit (cuda-keyring layout)
if [ -x /usr/local/cuda/bin/nvcc ]; then
	export PATH="/usr/local/cuda/bin:${PATH}"
	export CUDAToolkit_ROOT="${CUDAToolkit_ROOT:-/usr/local/cuda}"
	export CUDACXX="${CUDACXX:-/usr/local/cuda/bin/nvcc}"
fi

if command -v nvidia-smi >/dev/null 2>&1; then
	echo "build-native: GPUs:" >&2
	nvidia-smi --query-gpu=index,name,compute_cap --format=csv >&2 || true
fi
echo "build-native: OLLAMA_CUDA_BACKENDS=${OLLAMA_CUDA_BACKENDS} OLLAMA_CUDA_ARCHITECTURES=${OLLAMA_CUDA_ARCHITECTURES}" >&2
echo "build-native: OLLAMA_CMAKE_EXTRA=${OLLAMA_CMAKE_EXTRA}" >&2
echo "build-native: DEB_CFLAGS_APPEND=${DEB_CFLAGS_APPEND}" >&2

exec debian/build.sh "$@"
