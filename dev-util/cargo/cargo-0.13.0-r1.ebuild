# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

CARGO_SNAPSHOT_DATE="2016-09-01"
CRATES="
advapi32-sys-0.2.0
aho-corasick-0.5.2
bitflags-0.1.1
bitflags-0.7.0
bufstream-0.1.2
cargo-0.13.0
cargotest-0.1.0
cfg-if-0.1.0
cmake-0.1.17
crates-io-0.4.0
crossbeam-0.2.9
curl-0.3.2
curl-sys-0.2.1
docopt-0.6.82
env_logger-0.3.4
filetime-0.1.10
flate2-0.2.14
fs2-0.2.5
gcc-0.3.32
gdi32-sys-0.2.0
git2-0.4.4
git2-curl-0.5.0
glob-0.2.11
hamcrest-0.1.0
idna-0.1.0
kernel32-sys-0.2.2
lazy_static-0.2.1
libc-0.2.15
libgit2-sys-0.4.5
libressl-pnacl-sys-2.1.6
libssh2-sys-0.1.38
libz-sys-1.0.5
log-0.3.6
matches-0.1.2
memchr-0.1.11
miniz-sys-0.1.7
miow-0.1.3
net2-0.2.26
nom-1.2.4
num-0.1.34
num-bigint-0.1.33
num-complex-0.1.33
num-integer-0.1.32
num-iter-0.1.32
num-rational-0.1.32
num-traits-0.1.34
num_cpus-1.0.0
openssl-0.7.14
openssl-sys-0.7.14
openssl-sys-extras-0.7.14
pkg-config-0.3.8
pnacl-build-helper-1.4.10
rand-0.3.14
regex-0.1.73
regex-syntax-0.3.4
rustc-serialize-0.3.19
semver-0.2.3
strsim-0.3.0
tar-0.4.8
tempdir-0.3.5
term-0.4.4
thread-id-2.0.0
thread_local-0.2.6
toml-0.2.0
unicode-bidi-0.2.3
unicode-normalization-0.1.2
url-1.2.0
user32-sys-0.2.0
utf8-ranges-0.1.3
winapi-0.2.8
winapi-build-0.1.1
ws2_32-sys-0.2.1
"

inherit cargo bash-completion-r1

DESCRIPTION="The Rust's package manager"
HOMEPAGE="http://crates.io"
SRC_URI="https://github.com/rust-lang/cargo/archive/${PV}.tar.gz -> ${P}.tar.gz
	$(cargo_crate_uris ${CRATES})
	x86?   (
		https://static.rust-lang.org/cargo-dist/${CARGO_SNAPSHOT_DATE}/cargo-nightly-i686-unknown-linux-gnu.tar.gz ->
		cargo-snapshot-x86-${CARGO_SNAPSHOT_DATE}.tar.gz
	)
	amd64? (
		https://static.rust-lang.org/cargo-dist/${CARGO_SNAPSHOT_DATE}/cargo-nightly-x86_64-unknown-linux-gnu.tar.gz ->
		cargo-snapshot-amd64-${CARGO_SNAPSHOT_DATE}.tar.gz
	)"

RESTRICT="mirror"
LICENSE="|| ( MIT Apache-2.0 )"
SLOT="0"
KEYWORDS="~amd64 ~x86"

IUSE="doc libressl"

COMMON_DEPEND="sys-libs/zlib
	!libressl? ( dev-libs/openssl:0= )
	libressl? ( dev-libs/libressl:0= )
	net-libs/libssh2
	net-libs/http-parser"
RDEPEND="${COMMON_DEPEND}
	!dev-util/cargo-bin
	net-misc/curl[ssl]"
DEPEND="${COMMON_DEPEND}
	>=dev-lang/rust-1.9.0:stable
	dev-util/cmake
	sys-apps/coreutils
	sys-apps/diffutils
	sys-apps/findutils
	sys-apps/sed"

src_configure() {
	# Cargo only supports these GNU triples:
	# - Linux: <arch>-unknown-linux-gnu
	# - MacOS: <arch>-apple-darwin
	# - Windows: <arch>-pc-windows-gnu
	# where <arch> could be 'x86_64' (amd64) or 'i686' (x86)
	use amd64 && CTARGET="x86_64-unknown-linux-gnu"
	use x86 && CTARGET="i686-unknown-linux-gnu"

	# NOTE: 'disable-nightly' is used by crates (such as 'matches') to entirely
	# skip their internal libraries that make use of unstable rustc features.
	# Don't use 'enable-nightly' with a stable release of rustc as DEPEND,
	# otherwise you could get compilation issues.
	# see: github.com/gentoo/gentoo-rust/issues/13
	local myeconfargs=(
		--host=${CTARGET}
		--build=${CTARGET}
		--target=${CTARGET}
		--enable-optimize
		--disable-nightly
		--disable-verify-install
		--disable-debug
		--disable-cross-tests
	)
	econf "${myeconfargs[@]}"
}

src_compile() {
	# Building sources
	export CARGO_HOME="${ECARGO_HOME}"
	emake VERBOSE=1 PKG_CONFIG_PATH=""

	# Building HTML documentation
	use doc && emake doc
}

src_install() {
	emake prepare-image-${CTARGET} IMGDIR_${CTARGET}="${ED}/usr"

	# Install HTML documentation
	use doc && HTML_DOCS=("target/doc")
	einstalldocs

	dobashcomp "${ED}"/usr/etc/bash_completion.d/cargo
	rm -rf "${ED}"/usr/etc || die
}

src_test() {
	# Running unit tests
	# NOTE: by default 'make test' uses the copy of cargo (v0.0.1-pre-nighyly)
	# from the installer snapshot instead of the version just built, so the
	# ebuild needs to override the value of CFG_LOCAL_CARGO to avoid false
	# positives from unit tests.
	emake test \
		CFG_ENABLE_OPTIMIZE=1 \
		VERBOSE=1 \
		CFG_LOCAL_CARGO="${WORKDIR}"/${P}/target/${CTARGET}/release/cargo
}
