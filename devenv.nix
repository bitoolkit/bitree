{
  config,
  pkgs,
  lib,
  ...
}:

{
  android = {
    enable = true;
    flutter.enable = true;
    platforms.version = [
      "34"
      "35"
      "36"
    ];
    buildTools.version = [
      "35.0.0"
      "36.0.0"
    ];
    cmdLineTools.version = "11.0";
    ndk.enable = true;
    ndk.version = [ "28.2.13676358" ];
    emulator.enable = false;
    systemImages.enable = false;
    sources.enable = false;
    cmake.version = [ "3.22.1" ];
    android-studio.enable = false;
  };

  # The language server supplies its own JDK while Android builds use JDK 21
  languages.java.jdk.package = pkgs.jdk21;
  languages.java.lsp.package = pkgs.jdt-language-server;

  packages =
    with pkgs;
    [
      git
      just
      nixfmt
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      clang
      cmake
      ninja
      pkg-config
      gtk3
      libgcrypt
      libsecret
      webkitgtk_4_1
    ];

  env = {
    FLUTTER_GRADLE_PROJECT_DIR = "${config.devenv.state}/flutter-gradle";
  }
  // lib.optionalAttrs pkgs.stdenv.isLinux {
    LD_LIBRARY_PATH = lib.makeLibraryPath [
      pkgs.mesa
      pkgs.libGL
      pkgs.libsecret
    ];
    __EGL_VENDOR_LIBRARY_FILENAMES = "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json";
    LIBGL_DRIVERS_PATH = "${pkgs.mesa}/lib/dri";
    GBM_BACKENDS_PATH = "${pkgs.mesa}/lib/gbm";
    GIO_EXTRA_MODULES = "${pkgs.glib-networking}/lib/gio/modules";
  };

  enterShell = lib.mkAfter (
    ''
      mkdir -p "$FLUTTER_GRADLE_PROJECT_DIR"
      for entry in build.gradle.kts settings.gradle.kts src; do
        ln -sfn "$FLUTTER_ROOT/packages/flutter_tools/gradle/$entry" "$FLUTTER_GRADLE_PROJECT_DIR/$entry"
      done
    ''
    + lib.optionalString pkgs.stdenv.isLinux ''
      export LD_LIBRARY_PATH='$ORIGIN/lib:${
        lib.makeLibraryPath [
          pkgs.mesa
          pkgs.libGL
          pkgs.libsecret
        ]
      }:/run/opengl-driver/lib'
    ''
  );
}
