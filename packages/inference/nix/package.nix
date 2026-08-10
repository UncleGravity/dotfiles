{
  buildNpmPackage,
  coreutils,
  lib,
  makeWrapper,
  nodejs_24,
  openssh,
  python3,
  podman,
  rsync,
  skopeo,
  stdenv,
  systemd,
  util-linux,
}: let
  huggingfaceCli = python3.withPackages (ps: [ps.huggingface-hub]);
  runtimeInputs =
    [coreutils huggingfaceCli rsync]
    ++ lib.optionals stdenv.hostPlatform.isLinux [openssh podman skopeo systemd util-linux];
  source = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../package.json
      ../package-lock.json
      ../tsconfig.json
      ../src
      ../tests
    ];
  };
in
  buildNpmPackage {
    pname = "inference";
    version = "0.1.0";
    src = source;

    nodejs = nodejs_24;
    npmDepsHash = "sha256-rzDaxG1jNEWorvhbKj8j7AhhGuer3P1EuiaGg2yDPZg=";

    nativeBuildInputs = [makeWrapper];

    postInstall = ''
      for program in infer infer-cluster infer-instance infer-prepare infer-remote models; do
        wrapProgram $out/bin/$program \
          --prefix PATH : ${lib.makeBinPath runtimeInputs}
      done
    '';

    doCheck = true;
    checkPhase = ''
      runHook preCheck
      npm test
      runHook postCheck
    '';

    meta = {
      description = "Declarative model preparation and inference orchestration";
      license = lib.licenses.unfree;
      mainProgram = "infer";
      inherit (nodejs_24.meta) platforms;
    };
  }
