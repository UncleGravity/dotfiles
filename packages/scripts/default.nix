{ lib, stdenvNoCC, system }:

stdenvNoCC.mkDerivation {
  pname = "scripts";
  version = "1.0.0";

  src = ./.;

  installPhase = ''
    runHook preInstall
    export system=${system}
    bash ${./install.sh}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Personal shell scripts and completions";
    platforms = platforms.all;
  };
}
