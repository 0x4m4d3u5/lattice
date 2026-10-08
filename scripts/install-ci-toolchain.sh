#!/usr/bin/env bash
# Official tagged WASM compiler and its corresponding Moon source revision.
# All writes stay in a fresh MOON_HOME or caller-selected build/cache directories.
set -euo pipefail
: "${MOON_HOME:?Set MOON_HOME to a fresh task/job directory}"
if [[ -e "$MOON_HOME" ]]; then
  echo "Refusing to overwrite an existing toolchain: $MOON_HOME" >&2
  exit 1
fi
if [[ "$(node --version)" != "v26.10.0" ]]; then
  echo "Expected Node 26.10.0" >&2
  exit 1
fi
export RUSTUP_TOOLCHAIN=1.99.0
if [[ "$(rustc --version)" != "rustc 1.99.0 "* ]]; then
  echo "Expected Rust 1.99.0" >&2
  exit 1
fi
work_dir=$(mktemp -d)
archive="$work_dir/moonbit-wasm.tar.gz"
curl --fail --location 'https://github.com/moonbitlang/moonbit-compiler/releases/download/v0.10.14%2B7d59c7ec9/moonbit-wasm.tar.gz' -o "$archive"
expected_sha=3c5d21564b0e8bbfcfda95d374eda90427f6a5e238ce4639b711b69f43391f62
if command -v sha256sum >/dev/null; then
  actual_sha=$(sha256sum "$archive")
else
  actual_sha=$(shasum -a 256 "$archive")
fi
[[ "${actual_sha%% *}" == "$expected_sha" ]] || { echo "Compiler archive checksum mismatch" >&2; exit 1; }
mkdir -p "$work_dir/compiler" "$MOON_HOME/bin" "$MOON_HOME/lib"
tar xf "$archive" -C "$work_dir/compiler"
moon_commit=760759ca67539dd6b6ea59b1eba57731b3ef674a
[[ "$(cat "$work_dir/compiler/moon_version")" == "$moon_commit" ]] || { echo "Moon source revision mismatch" >&2; exit 1; }
git init "$work_dir/moon"
git -C "$work_dir/moon" fetch --depth 1 https://github.com/moonbitlang/moon.git "$moon_commit"
git -C "$work_dir/moon" checkout --detach FETCH_HEAD
[[ "$(git -C "$work_dir/moon" rev-parse HEAD)" == "$moon_commit" ]] || exit 1
export CARGO_HOME="${CARGO_HOME:-$work_dir/cargo-home}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$work_dir/cargo-target}"
cargo build --manifest-path "$work_dir/moon/Cargo.toml" --locked --release --jobs 2 --bin moon --bin moonrun
cp "$CARGO_TARGET_DIR/release/moon" "$CARGO_TARGET_DIR/release/moonrun" "$MOON_HOME/bin/"
for name in moonc moonfmt mooninfo; do
  { printf '%s\n' '#!/usr/bin/env -S node --stack-size=4096'; cat "$work_dir/compiler/$name.js"; } > "$MOON_HOME/bin/$name"
  chmod u+x "$MOON_HOME/bin/$name"
  cp -R "$work_dir/compiler/$name.assets" "$MOON_HOME/bin/"
done
cp -R "$work_dir/compiler/lib/." "$MOON_HOME/lib/"
cp -R "$work_dir/compiler/include" "$MOON_HOME/"
tar xf "$work_dir/compiler/core.tar.gz" -C "$MOON_HOME/lib"
export PATH="$MOON_HOME/bin:$PATH"
# The tagged compiler has a WebAssembly allocation defect; JS is the tested CI target.
moon -C "$MOON_HOME/lib/core" bundle --target js
moon version --all
