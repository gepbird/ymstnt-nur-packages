{
  lib,
  stdenv,
  autoPatchelfHook,
  rustPlatform,
  fetchFromGitHub,
  fetchFromGitLab,
  makeDesktopItem,
  copyDesktopItems,
  wrapGAppsHook3,
  pkg-config,
  clang,
  lld,
  meson,
  ninja,
  nasm,
  flex,
  bison,
  cmake,
  perl,
  git,
  python3,
  glib,
  glib-networking,
  openssl,
  libGL,
  libxkbcommon,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  libxcb,
  wayland,
  vulkan-loader,
  vulkan-headers,
  shaderc,
  fontconfig,
  freetype,
  alsa-lib,
  libpulseaudio,
  pipewire,
  libnice,
  libsoup_3,
  libgudev,
  libva,
  libass,
  srt,
  srtp,
  wavpack,
  libogg,
  libvorbis,
  libtheora,
  opus,
  flac,
  libheif,
  orc,
  zlib,
  libxml2,
  usrsctp,
  pcre2,
  libffi,
  util-linux,
  libselinux,
  libsepol,
  gnutls,
  gupnp-igd,
  sqlite,
  libpsl,
  brotli,
  nghttp2,
  nettle,
  libtasn1,
  libidn2,
  libunistring,
  gmp,
  p11-kit,
  udev,
  libdrm,
  libthai,
  libdatrie,
  graphite2,
  libxdmcp,
  libepoxy,
  libxtst,
  dav1d,
}:
let
  # Opus's GitHub sources need an explicit version for pkg-config. Keep this
  # workaround local, and reuse nixpkgs's package when it already has the fix.
  opusForFcast =
    if lib.hasInfix "PACKAGE_VERSION" (opus.postPatch or "") then
      opus
    else
      opus.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          echo 'PACKAGE_VERSION="${old.version}"' > package_version
        '';
      });
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "fcast-receiver";
  version = "3.0.4";

  src = fetchFromGitHub {
    owner = "futo-org";
    repo = "fcast";
    tag = "desktop-receiver-${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-ujMlXNg6bObQXZSVKthMkXJW9M+iTdGVUuDETyk+AeY=";
  };

  cargoHash = "sha256-mI7Io8emoxs9B54AJGSmf5+2UoTaZ3s5prGu3e+zmgY=";
  buildAndTestSubdir = "receivers/desktop";

  # The receiver relies on FCast's patched GStreamer. Fetch its sources and
  # FFmpeg subproject ahead of time instead of downloading in Cargo build.rs.
  gstSrc = fetchFromGitLab {
    domain = "gitlab.futo.org";
    owner = "fcast";
    repo = "gstreamer";
    rev = "eca31bb1c6665f327bdc7e235d2e90c97115311c";
    hash = "sha256-6+xmGUkSAbJHpNw3GJcmRYQ/YMQhhJjzHvyVZCmWHRs=";
  };

  ffmpegSrc = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "gstreamer/meson-ports";
    repo = "ffmpeg";
    rev = "cde7209117ec2be9da087b9e5f96d48450fdecd2";
    hash = "sha256-1S+QMj3BeYFRtsUZPkqXJmxGICP9mz0TFALUaHNpqT4=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    pkg-config
    clang
    lld
    meson
    ninja
    nasm
    flex
    bison
    cmake
    perl
    git
    (python3.withPackages (ps: [
      ps.jinja2
      ps.mako
      ps.setuptools
    ]))
    rustPlatform.bindgenHook
    copyDesktopItems
    wrapGAppsHook3
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    glib
    glib-networking
    openssl
    libGL
    libxkbcommon
    libx11
    libxcursor
    libxi
    libxrandr
    libxcb
    wayland
    vulkan-loader
    vulkan-headers
    shaderc
    fontconfig
    freetype
    alsa-lib
    libpulseaudio
    pipewire
    libnice
    libsoup_3
    libgudev
    libva
    libass
    srt
    srtp
    wavpack
    libogg
    libvorbis
    libtheora
    opusForFcast
    flac
    libheif
    orc
    zlib
    libxml2
    usrsctp
    # gstreamer-src queries pkg-config --static, including the private
    # dependencies of the system libraries it links dynamically.
    pcre2
    libffi
    util-linux
    libselinux
    libsepol
    gnutls
    gupnp-igd
    sqlite
    libpsl
    brotli
    nghttp2
    nettle
    libtasn1
    libidn2
    libunistring
    gmp
    p11-kit
    udev
    libdrm
    libthai
    libdatrie
    graphite2
    libxdmcp
    libepoxy
    libxtst
    dav1d
  ];

  dontUseMesonConfigure = true;
  dontUseCmakeConfigure = true;
  dontUseNinjaBuild = true;
  dontUseNinjaCheck = true;
  dontUseNinjaInstall = true;
  env.GSTREAMER_SRC_OFFLINE = "1";

  postPatch = ''
    substituteInPlace .cargo/config.toml --replace-fail 'link-arg=--ld-path=wild' 'link-arg=-fuse-ld=lld'
  '';

  preBuild = ''
    cp -r ${finalAttrs.gstSrc} gst-source
    chmod -R u+w gst-source
    cp -r ${finalAttrs.ffmpegSrc} gst-source/subprojects/FFmpeg
    chmod -R u+w gst-source/subprojects/FFmpeg
    patchShebangs gst-source crates/libplacebo-sys/libplacebo
    export GSTREAMER_SRC_SOURCE="$PWD/gst-source"
    export GSTREAMER_SRC_JOBS="$NIX_BUILD_CORES"
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "org.fcast.Receiver";
      desktopName = "FCast Receiver";
      genericName = "Media Streaming Receiver";
      exec = "fcast-receiver";
      icon = "fcast-receiver";
      comment = "Receive audio and video streams using FCast";
      categories = [
        "AudioVideo"
        "Player"
      ];
    })
  ];

  postInstall = ''
    mv $out/bin/desktop-receiver $out/bin/fcast-receiver
    for size in 128 256 512; do
      install -Dm644 receivers/extra/icon$size.png \
        $out/share/icons/hicolor/''${size}x$size/apps/fcast-receiver.png
    done
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libGL
          libxkbcommon
          libx11
          libxcursor
          libxi
          libxrandr
          libxcb
          fontconfig
          wayland
          vulkan-loader
        ]
      }
    )
  '';

  meta = {
    description = "Receiver for the open-source FCast media streaming protocol";
    homepage = "https://fcast.org/";
    changelog = "https://github.com/futo-org/fcast/releases/tag/desktop-receiver-${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ ymstnt ];
    mainProgram = "fcast-receiver";
    platforms = lib.platforms.linux;
  };
})
