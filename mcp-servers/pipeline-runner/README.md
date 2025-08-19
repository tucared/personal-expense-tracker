# Pipeline Runner MCP Server

Simple MCP server for testing expense tracker pipelines during development.
Provides single-pipeline testing with automated process management.

## Features

- **Single Pipeline Constraint**: Only one pipeline runs at a time (port 8080)
- **Four Core Operations**: `start_pipeline`, `trigger_pipeline`, `stop_pipeline`, `run_pipeline`
- **Automatic Process Management**: Monitors startup, handles cleanup
- **Integration Ready**: Works with existing Makefile targets

## Setup

### Install Dependencies

```bash
cd mcp-servers/pipeline-runner
uv sync
```

### Claude Desktop Configuration

Add to your Claude Desktop config:

```json
{
  "mcpServers": {
    "pipeline-runner": {{
      "command": "uv",
      "args": [
        "--directory",
        "mcp-servers/pipeline-runner",
        "run",
        "runner.py"]
    }
  }
}
```

## Usage

### Quick Testing (Recommended)

```python
# Complete test cycle: start → trigger → stop
run_pipeline("notion")           # Test notion pipeline in dev
run_pipeline("gsheets", "prod")  # Test gsheets pipeline in prod
```

### Manual Control

```python
# Step-by-step control
start_pipeline("notion", "dev")  # Start pipeline
trigger_pipeline()              # Send HTTP POST to trigger
stop_pipeline()                 # Clean shutdown

# Check status
get_status()                    # Current state
```

## Operations

### start_pipeline(service, env="dev")

Starts a pipeline service using existing Makefile targets.

- **service**: `"notion"` or `"gsheets"`
- **env**: `"dev"` or `"prod"`
- **Returns**: Status message
- **Behavior**:
  - Runs `make run-{service}-{env}` with `PORT=8080`
  - Waits for "Running on http://" message (up to 10 seconds)
  - Fails if another pipeline is already running

### trigger_pipeline()

Sends HTTP POST to the running pipeline.

- **Returns**: HTTP response status and content (truncated)
- **Behavior**:
  - POST to `http://localhost:8080`
  - 30-second timeout
  - Requires active pipeline

### stop_pipeline()

Stops the currently running pipeline.

- **Returns**: Confirmation message
- **Behavior**:
  - Graceful termination with SIGTERM
  - Force kill if needed
  - Cleans up process state

### run_pipeline(service, env="dev")

Complete test cycle in one call.

- **Combines**: start → trigger → stop
- **Returns**: Multi-line status with all operation results
- **Use Case**: Quick testing after code changes

### get_status()

Returns current pipeline state.

- **Returns**: Running pipeline info or "No pipeline running"
- **Behavior**: Checks process health, cleans up dead processes

## Error Handling

### Common Errors

- `❌ notion-gsheets is running. Stop it first.` - Only one pipeline allowed
- `❌ Invalid service. Use: notion, gsheets` - Check service name
- `❌ Makefile not found. Run from project root.` - Wrong directory
- `❌ notion-dev failed to start within 10 seconds` - Startup timeout
- `❌ No pipeline running. Start one first.` - Trigger without start

### Process Safety

- Monitors stdout for startup confirmation
- Handles orphaned processes from previous runs
- Graceful shutdown on exit signals
- Automatic cleanup on process death

## Development

### Run Linting

```bash
uv run ruff check .
uv run mypy .
```

### Run Formatting

```bash
uv run ruff format .
```

### Testing

Test with a real pipeline:

```bash
# From project root
cd mcp-servers/pipeline-runner
uv run runner &

# In another terminal, test the MCP tools
# (requires MCP client or Claude Desktop integration)
```

## Integration with Development Workflow

1. **Modify Pipeline Code**: Edit files in `opentofu/modules/{service}_pipeline/src/`
2. **Test Changes**: Use `run_pipeline("{service}")`
3. **Validate Data**: Check results with DuckDB MCP
4. **Iterate**: Repeat until satisfied

## Troubleshooting

### Pipeline Won't Start

- Verify you're in project root directory (Makefile must exist)
- Check that `make run-{service}-{env}` works manually
- Ensure port 8080 is available
- Review startup logs in terminal

### Pipeline Trigger Fails

- Confirm pipeline started successfully (check `get_status()`)
- Verify Functions Framework is listening on port 8080
- Check for authentication/permission issues

### Process Management Issues

- Use `stop_pipeline()` to clean up
- Restart Claude Desktop if state gets corrupted
- Check for conflicting processes on port 8080

## Architecture

### State Management

```python
current_pipeline = None  # "notion-dev", "gsheets-prod", or None
current_process = None   # subprocess.Popen object
```

### Process Lifecycle

1. **Start**: Fork make process, monitor stdout for "Running on http://"
2. **Ready**: HTTP server accepting connections on port 8080
3. **Trigger**: POST request with response validation
4. **Stop**: SIGTERM → SIGKILL if needed, cleanup state

### Error Recovery

- Dead process detection via `poll()`
- Automatic state cleanup on detection
- Signal handlers for clean shutdown
- Timeout handling for startup and HTTP requests

## Requirements

- Python 3.10+
- UV package manager
- Existing project Makefile targets
- FastMCP and httpx dependencies
- GCP authentication (for pipeline execution)
