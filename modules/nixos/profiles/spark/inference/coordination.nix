{
  lib,
  node,
  pkgs,
  username,
  ...
}: {
  clan.core.vars.generators = lib.mkIf node.controller {
    spark-coordination-spark = {
      files = {
        id_ed25519.neededFor = "services";
        "id_ed25519.pub".secret = false;
      };
      runtimeInputs = [pkgs.openssh];
      script = ''
        ssh-keygen -t ed25519 -N "" -C "" -f "$out/id_ed25519"
        ssh-keygen -y -f "$out/id_ed25519" > "$out/id_ed25519.pub"
      '';
    };

    spark-huggingface-spark = {
      prompts.token = {
        description = "Hugging Face token for the Spark controller";
        type = "hidden";
        persist = true;
      };
      files.token = {
        owner = username;
        mode = "0400";
      };
      script = ''
        test -s "$out/token"
      '';
    };
  };
}
