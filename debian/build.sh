#!/bin/sh
# Regenerate changelog from git, then build binary packages into debian/.
set -eu
cd "$(dirname "$0")/.."
debian/update-changelog

ver=$(debian/get-version)
full="${ver}-1"
arch=$(dpkg --print-architecture)

exec dpkg-buildpackage -us -uc -b \
	--buildinfo-file="debian/ollama_${full}_${arch}.buildinfo" \
	--changes-file="debian/ollama_${full}_${arch}.changes" \
	--buildinfo-option=-udebian \
	--changes-option=-udebian \
	"$@"
