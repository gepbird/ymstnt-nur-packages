{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_12,
  nodejs_22,
  electron,
  makeWrapper,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "eidos-lite";
  version = "0.34.0";

  src = fetchFromGitHub {
    owner = "mayneyao";
    repo = "eidos";
    tag = "lite-v${finalAttrs.version}";
    hash = "sha256-KvS7rIqXfNPAMowuoM7iUvlctHD1Pr5VcGmCqry5OEg=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_12;
    fetcherVersion = 5;
    hash = "";
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm_12
    pnpmConfigHook
    makeWrapper
  ];

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  buildPhase = ''
    runHook preBuild

    pnpm --filter @eidos.space/eidos-file build
    pnpm --filter @eidos.space/eidos-file-ui build
    pnpm --filter @eidos.space/markdown build
    pnpm --filter @eidos.space/eidos-lite-desktop exec electron-builder --dir \
      -c.electronDist=${electron}/libexec/electron \
      -c.electronVersion=${electron.version}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/eidos-lite $out/bin
    cp -r apps/eidos-lite-desktop/dist/*-unpacked/resources/* $out/share/eidos-lite/

    makeWrapper ${electron}/bin/electron $out/bin/eidos-lite \
      --add-flags "$out/share/eidos-lite/app.asar"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "^v(\\d+\\.\\d+\\.\\d+)$"
    ];
  };

  meta = {
    description = "A single-file relational spreadsheet for you and your agent";
    homepage = "https://eidos.space";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
  };
})
