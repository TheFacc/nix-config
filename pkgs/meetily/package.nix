# Meetily: local meeting recorder, transcriber and summarizer
# (https://github.com/Zackriya-Solutions/meetily). Upstream ships no Linux
# binaries, so build the Tauri app from source; layout follows nixpkgs' handy.
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs,
  cargo-tauri,
  jq,
  pkg-config,
  cmake,
  shaderc,
  spirv-headers,
  wrapGAppsHook3,
  writableTmpDirAsHomeHook,
  source-sans,

  webkitgtk_4_1,
  gtk3,
  glib,
  libsoup_3,
  openssl,
  alsa-lib,
  libayatana-appindicator,
  vulkan-loader,
  vulkan-headers,
  glib-networking,
  onnxruntime,
  ffmpeg,
  pipewire,
  alsa-plugins,
  symlinkJoin,
}:
let
  target = stdenv.hostPlatform.rust.rustcTarget;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "meetily";
  version = "0.4.1";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "Zackriya-Solutions";
    repo = "meetily";
    tag = "v${finalAttrs.version}";
    hash = "sha256-rnrByZHPNCErCPA6WfJFeEGQxQAF4KyCXzOuXtKjHr4=";
  };

  cargoHash = "sha256-TlmLc+3uUxvTlMn+8/Q6WOBk0eS/8PInPd+TQeaWj1c=";

  pnpmRoot = "frontend";
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    sourceRoot = "${finalAttrs.src.name}/frontend";
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-DSN+2S3sUKyBWf8ytndyeU+XksXvkrNSXCIdVD/wg4E=";
  };

  # Vulkan runs whisper and the summary LLM on the GPU without CUDA.
  buildAndTestSubdir = "frontend";
  cargoBuildFlags = [ "--features" "vulkan" ];

  postPatch = ''
    patch_json() {
      jq "$2" "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    }
    # No updater signing key, and Linux releases don't exist to update from.
    patch_json frontend/src-tauri/tauri.conf.json '
      .bundle.createUpdaterArtifacts = false |
      .plugins.updater.endpoints = []
    '

    # next/font/google downloads the font at build time
    cp ${source-sans}/share/fonts/truetype/SourceSans3-{Regular,Medium,Semibold,Bold}.ttf frontend/src/app/
    substituteInPlace frontend/src/app/layout.tsx \
      --replace-fail "import { Source_Sans_3 } from 'next/font/google'" \
                     "import localFont from 'next/font/local'" \
      --replace-fail "Source_Sans_3({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-source-sans-3',
})" "localFont({
  src: [
    { path: './SourceSans3-Regular.ttf', weight: '400' },
    { path: './SourceSans3-Medium.ttf', weight: '500' },
    { path: './SourceSans3-Semibold.ttf', weight: '600' },
    { path: './SourceSans3-Bold.ttf', weight: '700' },
  ],
  variable: '--font-source-sans-3',
})"

    substituteInPlace "$cargoDepsCopy"/*/libappindicator-sys-*/src/lib.rs \
      --replace-fail 'libayatana-appindicator3.so.1' '${libayatana-appindicator}/lib/libayatana-appindicator3.so.1'
  '';

  nativeBuildInputs = [
    pnpmConfigHook
    pnpm_10
    nodejs
    cargo-tauri.hook
    jq
    pkg-config
    cmake
    shaderc
    spirv-headers
    wrapGAppsHook3
    writableTmpDirAsHomeHook
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    webkitgtk_4_1
    gtk3
    glib
    libsoup_3
    openssl
    alsa-lib
    libayatana-appindicator
    vulkan-loader
    vulkan-headers
    glib-networking
    onnxruntime
  ];

  # cmake is only for the whisper/llama build scripts
  dontUseCmakeConfigure = true;

  env = {
    ORT_LIB_LOCATION = "${lib.getLib onnxruntime}/lib";
    ORT_PREFER_DYNAMIC_LINK = "1";
    NEXT_TELEMETRY_DISABLED = "1";
  };

  # Tauri bundles these two sidecars from binaries/<name>-<target>; build.rs
  # would otherwise download a static ffmpeg.
  preBuild = ''
    export CMAKE_PREFIX_PATH="${spirv-headers}''${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
    export NIX_CFLAGS_COMPILE="-isystem ${spirv-headers}/include ''${NIX_CFLAGS_COMPILE:-}"

    cargo build --offline --release -j "$NIX_BUILD_CORES" --target ${target} \
      -p llama-helper --features vulkan

    mkdir -p frontend/src-tauri/binaries
    cp target/${target}/release/llama-helper frontend/src-tauri/binaries/llama-helper-${target}
    cp ${lib.getExe ffmpeg} frontend/src-tauri/binaries/ffmpeg-${target}
  '';

  # Keep the sidecars off the user's PATH: the app finds ffmpeg through the
  # wrapper's PATH and llama-helper through MEETILY_LLAMA_HELPER.
  postInstall = ''
    mkdir -p $out/libexec/meetily
    mv $out/bin/llama-helper $out/libexec/meetily/
    rm $out/bin/ffmpeg
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath [ ffmpeg ]}
      --set MEETILY_LLAMA_HELPER $out/libexec/meetily/llama-helper
      --set ALSA_PLUGIN_DIR ${finalAttrs.passthru.alsaPluginDirectory}
      --set WEBKIT_DISABLE_DMABUF_RENDERER 1
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ vulkan-loader ]}
    )
  '';

  doCheck = false;

  passthru.alsaPluginDirectory = symlinkJoin {
    name = "meetily-alsa-plugins";
    paths = [
      "${pipewire}/lib/alsa-lib"
      "${alsa-plugins}/lib/alsa-lib"
    ];
  };

  meta = {
    description = "Privacy-first AI meeting assistant with local transcription and summaries";
    homepage = "https://github.com/Zackriya-Solutions/meetily";
    license = lib.licenses.mit;
    mainProgram = "meetily";
    platforms = lib.platforms.linux;
  };
})
