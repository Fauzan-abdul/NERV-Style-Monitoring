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

Terminal notes
If your terminal supports 24-bit color, you get the smooth teal-to-blue gradient. Otherwise it falls back to 256 colors, which looks a bit greener on the left. You can force the 24-bit gradient with `COLORTERM=truecolor ./monitor.sh all.`
The preview shows low usage, so most pills are dim. At higher load more of the row lights up, ending in blue.
Each subject is now 4 lines tall instead of 2, so live mode and all take more vertical space. Anything under about 50 rows will scroll a bit.
