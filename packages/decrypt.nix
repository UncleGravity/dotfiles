{
  pkgs,
  lib,
  ...
}:
pkgs.writeShellApplication {
  name = "decrypt";
  runtimeInputs = with pkgs; [
    age
    _1password-cli
  ];
  text = ''
    # Check if more than one argument is provided
    if [ "$#" -gt 1 ]; then
        echo "Usage: $0 [encrypted_file]" >&2
        echo "Decrypts the specified file or reads from stdin if no file is given." >&2
        exit 1
    fi

    INPUT_SOURCE=""
    # If an argument is provided, use it as the source file
    if [ "$#" -eq 1 ]; then
        SOURCE_FILE="$1"
        # Check if the source file exists
        if [ ! -f "$SOURCE_FILE" ]; then
            echo "Error: File '$SOURCE_FILE' not found." >&2
            exit 1
        fi
        INPUT_SOURCE="$SOURCE_FILE"
    # If no argument is provided, use stdin ('-')
    else
        INPUT_SOURCE="-"
    fi

    # Decrypt using age with 1Password key
    # -d: decrypt, -i: identity file from process substitution
    if ! age -d -i <(op read "op://Personal/master-ssh-key/private key") "$INPUT_SOURCE"; then
        echo "Error during decryption." >&2
        exit 1
    fi
  '';
  meta = {
    description = "Decrypt files using age with 1Password integration";
    platforms = lib.platforms.darwin;
    mainProgram = "decrypt";
  };
}
