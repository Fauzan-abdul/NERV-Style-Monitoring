# NERV-Style Linux System Monitor

Monitor CPU, memory, and disk usage in a terminal HUD, with an interactive menu, live mode, and optional logging.

## Usage

```bash
chmod +x monitor.sh
./monitor.sh
```

Run a specific view with `./monitor.sh cpu`, `mem`, `disk`, or `all`. Use `./monitor.sh live` for automatic refresh, or `./monitor.sh help` to see all options.

Logs are saved to `~/project-monitoring/logs/monitor.log` by default. Set `LOG_DIR` to change the log directory. Set `NO_COLOR=1` to disable colors or `FORCE_COLOR=1` to force them.

Requires Bash and standard Linux utilities such as `ps`, `df`, `free`, and `awk`.
