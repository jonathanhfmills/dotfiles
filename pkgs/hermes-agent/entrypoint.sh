#!/bin/bash
set -uo pipefail

echo "Wanda is awake (Hermes Brain, air-gapped)"

# Main loop: watch NAS queue for tasks, process via vLLM
QUEUE_DIR="/workspace/shared/queue/nas"
RESULTS_DIR="/workspace/shared/queue/results"

process_task() {
  local task_file="$1"
  local task_id
  task_id=$(basename "$task_file" .json)

  echo "Processing task $task_id"
  local result_dir="$RESULTS_DIR/$task_id"
  mkdir -p "$result_dir"

  # Route via vLLM OpenAI-compatible API
  # Handles null content (reasoning-only responses) gracefully
  python3 << PYEOF || true
import json, os, urllib.request

base_url = os.environ.get('OPENAI_BASE_URL', 'http://172.17.0.1:11434/v1')
api_key = os.environ.get('OPENAI_API_KEY', 'ollama')
model = os.environ.get('LLM_MODEL', 'Qwen/Qwen3.5-9B')

# Load Wanda identity for system prompt
identity = ''
for f in ['IDENTITY.md', 'SOUL.md', 'SYSTEM.md']:
    path = f'/workspace/wanda/{f}'
    try:
        identity += open(path).read() + '\n'
    except FileNotFoundError:
        pass

memory = ''
try:
    memory = open('/workspace/wanda/MEMORY.md').read()
except FileNotFoundError:
    pass

system_prompt = identity + '\n# MEMORY\n' + memory if memory else identity

prompt_text = open('$task_file').read()
task = json.loads(prompt_text)
user_prompt = task.get('prompt', '')

payload = json.dumps({
    'model': model,
    'messages': [
        {'role': 'system', 'content': system_prompt},
        {'role': 'user', 'content': user_prompt},
    ],
    'temperature': 0.7,
    'max_tokens': 4096,
}).encode()

req = urllib.request.Request(
    f'{base_url}/chat/completions',
    data=payload,
    headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {api_key}'},
)
try:
    resp = urllib.request.urlopen(req, timeout=120)
    result = json.loads(resp.read())
    msg = result['choices'][0]['message']
    content = msg.get('content') or ''
    reasoning = msg.get('reasoning') or ''
    output = content if content else reasoning
    if not output:
        output = json.dumps(msg, indent=2)
    with open('$result_dir/output.txt', 'w') as f:
        f.write(output)
    print(f'Task $task_id completed ({len(output)} chars)')
except Exception as e:
    with open('$result_dir/error.txt', 'w') as f:
        f.write(str(e))
    print(f'Task $task_id failed: {e}')
PYEOF

  mv "$task_file" "$RESULTS_DIR/$task_id.done.json" 2>/dev/null || true
  echo "Task $task_id done"
}

while true; do
  for task_file in "$QUEUE_DIR"/*.json; do
    [ -f "$task_file" ] || continue
    process_task "$task_file"
  done
  sleep 10
done
