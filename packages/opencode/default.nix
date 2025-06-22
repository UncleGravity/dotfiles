{
  lib,
  stdenv,
  bun,
  inputs,
  ...
}:

stdenv.mkDerivation {
  pname = "opencode";
  version = "unstable-${builtins.substring 0 7 inputs.opencode.rev}";
  src = inputs.opencode;

  # Disable sandbox to allow network access for dependency fetching
  # The build is still reproducible thanks to the upstream lockfiles
  __noChroot = true;

  nativeBuildInputs = [ bun ];

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    bun install --no-save --ignore-scripts
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/opencode

    # Install the entire workspace
    cp -r . $out/lib/opencode/

    # Create wrapper script
    cat > $out/bin/opencode << EOF
#!/usr/bin/env bash
cd $out/lib/opencode
exec ${bun}/bin/bun packages/opencode/src/index.js "\$@"
EOF
    chmod +x $out/bin/opencode

    runHook postInstall
  '';

  meta = with lib; {
    description = "AI coding agent, built for the terminal";
    homepage = "https://opencode.ai";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
