{
  pkgs,
  lib,
  ...
}: let
  pushScript = pkgs.writeShellApplication {
    name = "push";
    runtimeInputs = with pkgs; [
      curl
      jq
      coreutils
      gnused
    ];
    text = ''
      # Check if required environment variables are set
      if [ -z "''${PUSHOVER_USER_KEY:-}" ]; then
        echo "Error: PUSHOVER_USER_KEY environment variable is not set." >&2
        exit 1
      fi

      if [ -z "''${PUSHOVER_APP_KEY_DEFAULT:-}" ]; then
        echo "Error: PUSHOVER_APP_KEY_DEFAULT environment variable is not set." >&2
        exit 1
      fi

      # Help/usage
      usage() {
        printf "Usage: %s [options] [MESSAGE]\n\n" "$(basename "$0")"
        printf "Send a Pushover notification. Reads MESSAGE from arguments or standard input if no arguments are provided.\n"
        printf "If neither arguments nor standard input is provided, sends \"PING\".\n\n"
        printf "Options:\n"
        printf "  -m, --message TEXT       Notification message (or pass via pipe/positional; default \"PING\")\n"
        printf "  -i, --image PATH         Attach an image (max 5 MiB)\n"
        printf "  -t, --title TEXT         Notification title\n"
        printf "  -u, --url URL            Include a URL\n"
        printf "  -T, --url-title TEXT     Title for the URL\n"
        printf "  -S, --timestamp SECS     Unix timestamp for the message\n"
        printf "  -d, --device DEVICE      Target device name (otherwise all devices)\n"
        printf "  -H, --html               Enable HTML formatting in the message\n"
        printf "  -h, --help               Show this help message and exit\n"
      }

      # Process long options and separate positional arguments
      PROCESSED_ARGS=()
      POSITIONAL_ARGS=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --message)   PROCESSED_ARGS+=(-m "$2");       shift 2 ;;
          --image)     PROCESSED_ARGS+=(-i "$2");       shift 2 ;;
          --title)     PROCESSED_ARGS+=(-t "$2");       shift 2 ;;
          --url)       PROCESSED_ARGS+=(-u "$2");       shift 2 ;;
          --url-title) PROCESSED_ARGS+=(-T "$2");       shift 2 ;;
          --timestamp) PROCESSED_ARGS+=(-S "$2");       shift 2 ;;
          --device)    PROCESSED_ARGS+=(-d "$2");       shift 2 ;;
          --html)      PROCESSED_ARGS+=(-H);            shift   ;;
          --help)      PROCESSED_ARGS+=(-h);            shift   ;;
          --)          shift; POSITIONAL_ARGS+=("$@"); break ;;
          -*)          PROCESSED_ARGS+=("$1");          shift   ;;
          *)           POSITIONAL_ARGS+=("$1");         shift   ;;
        esac
      done
      # Set arguments to processed options followed by positional args
      set -- "''${PROCESSED_ARGS[@]}" "''${POSITIONAL_ARGS[@]}"

      # Defaults
      MESSAGE=""
      IMAGE=""
      TITLE=""
      URL=""
      URL_TITLE=""
      TIMESTAMP=""
      DEVICE=""
      HTML_ENABLED=0

      # Parse short options
      while getopts "m:i:t:u:T:S:d:Hh" opt; do
        case "$opt" in
          m) MESSAGE=$OPTARG      ;;
          i) IMAGE=$OPTARG        ;;
          t) TITLE=$OPTARG        ;;
          u) URL=$OPTARG          ;;
          T) URL_TITLE=$OPTARG    ;;
          S) TIMESTAMP=$OPTARG    ;;
          d) DEVICE=$OPTARG       ;;
          H) HTML_ENABLED=1       ;;
          h) usage; exit 0        ;;
          *) usage; exit 1        ;;
        esac
      done
      shift $((OPTIND -1))

      # Determine MESSAGE (positional, piped, or default)
      if [[ -z "$MESSAGE" ]]; then
        if [[ $# -gt 0 ]]; then
          MESSAGE="$*"
        elif ! [[ -t 0 ]]; then
          MESSAGE=$(cat)
        else
          MESSAGE="PING"
        fi
      fi

      # Validate timestamp
      if [[ -n "$TIMESTAMP" && ! "$TIMESTAMP" =~ ^[0-9]+$ ]]; then
        echo "Error: --timestamp must be a positive integer." >&2
        exit 1
      fi

      # Validate image file & size
      if [[ -n "$IMAGE" ]]; then
        [[ -f "$IMAGE" ]] || { echo "Error: File not found: $IMAGE" >&2; exit 1; }
        FILE_SIZE=$(stat -c%s "$IMAGE" 2>/dev/null || stat -f%z "$IMAGE")
        if (( FILE_SIZE > 5242880 )); then
          echo "Error: Image exceeds 5 MiB limit." >&2
          exit 1
        fi
      fi

      # Set default device if not provided
      if [[ -z "$DEVICE" ]]; then
        DEVICE="CRISPR"
      fi

      # Send notification
      curl -sSf -X POST https://api.pushover.net/1/messages.json \
        -F "token=''${PUSHOVER_APP_KEY_DEFAULT}" \
        -F "user=''${PUSHOVER_USER_KEY}" \
        -F "message=''${MESSAGE}" \
        ''${TITLE:+-F "title=''${TITLE}"} \
        ''${URL:+-F "url=''${URL}"} \
        ''${URL_TITLE:+-F "url_title=''${URL_TITLE}"} \
        ''${TIMESTAMP:+-F "timestamp=''${TIMESTAMP}"} \
        ''${IMAGE:+-F "attachment=@''${IMAGE}"} \
        ''${DEVICE:+-F "device=''${DEVICE}"} \
        ''${HTML_ENABLED:+-F "html=1"}

      exit $?
    '';
  };

  completion = pkgs.writeTextFile {
    name = "_push";
    text = /* zsh */ ''
      #compdef push

      _push_devices() {
        local devices
        devices=$(curl -s \
          --form-string "token=''${PUSHOVER_APP_KEY_DEFAULT}" \
          --form-string "user=''${PUSHOVER_USER_KEY}" \
          https://api.pushover.net/1/users/validate.json | jq -r '.devices[]')
        _values 'device' ''${(f)devices}
      }

      _arguments \
        '--message[Notification message]:message:' \
        '--image[Attach an image]:image:_files' \
        '--title[Notification title]:title:' \
        '--url[Include a URL]:url:' \
        '--url-title[Title for the URL]:url_title:' \
        '--timestamp[Unix timestamp]:timestamp:_integer' \
        '--device[Target device]:device:_push_devices' \
        '--help[Show help]' \
        '*:message:'
    '';
    destination = "/share/zsh/site-functions/_push";
  };
in
pkgs.symlinkJoin {
  name = "push";
  paths = [pushScript completion];
  meta = {
    description = "Send Pushover notifications from the command line";
    platforms = lib.platforms.all;
    mainProgram = "push";
  };
}
