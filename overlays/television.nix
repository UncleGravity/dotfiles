{inputs}:
#
final: prev: {
  television = 
    if inputs ? television
    then inputs.television.packages.${prev.system}.default
    else prev.television or (throw "television not available in nixpkgs and flake input not found");
}