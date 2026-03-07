{ lib
, writeShellApplication
, curl
, jq
, coreutils
, hostname
}:

writeShellApplication {
  name = "aw-watcher-bash";

  runtimeInputs = [ curl jq coreutils hostname ];

  text = ''
    if [ $# -ne 3 ]; then
      echo "Usage: aw-watcher-bash <command> <cwd> <exit_code>" >&2
      exit 1
    fi

    COMMAND="$1"
    CWD="$2"
    EXIT_CODE="$3"

    HOST=$(hostname)
    BUCKET_ID="aw-watcher-bash_$HOST"
    AW_URL="http://localhost:5600/api/0"
    FLAG="/tmp/.aw-watcher-bash-init-$HOST"

    # Lazily create the bucket (once per boot).
    if [ ! -f "$FLAG" ]; then
      curl -s -o /dev/null -X POST "$AW_URL/buckets/$BUCKET_ID" \
        -H "Content-Type: application/json" \
        -d "{\"client\": \"aw-watcher-bash\", \"type\": \"currentwindow\", \"hostname\": \"$HOST\"}" \
        && touch "$FLAG"
    fi

    # Build the event JSON safely via jq.
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    EVENT=$(jq -n \
      --arg title "$COMMAND" \
      --arg app "bash" \
      --arg command "$COMMAND" \
      --arg cwd "$CWD" \
      --arg exit_code "$EXIT_CODE" \
      --arg timestamp "$TIMESTAMP" \
      '{
        timestamp: $timestamp,
        duration: 0,
        data: {
          title: $title,
          app: $app,
          command: $command,
          cwd: $cwd,
          exit_code: ($exit_code | tonumber)
        }
      }')

    curl -s -o /dev/null -X POST "$AW_URL/buckets/$BUCKET_ID/heartbeat?pulsetime=120" \
      -H "Content-Type: application/json" \
      -d "$EVENT"
  '';

  meta = {
    description = "ActivityWatch watcher for bash commands via PROMPT_COMMAND";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "aw-watcher-bash";
  };
}
