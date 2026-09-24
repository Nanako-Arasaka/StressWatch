# StressWatch signing refresh

`refresh-free-signing.sh` rebuilds the Debug app with automatic signing and
reinstalls it on the first connected physical iPhone. When a StressWatch
provisioning profile has less than 48 hours remaining, the script archives the
local cached profile before asking Xcode to refresh it.

Install or update the LaunchAgent:

```bash
./Scripts/install-signing-automation.sh
```

The task runs at 15:00 on days 1, 6, 11, 16, 21, and 26 of each month. The Mac
must be logged in and awake, and the paired iPhone must be reachable by Xcode.
Logs are written to `~/Library/Logs/StressWatch/`.

For a specific device, set both `STRESSWATCH_XCODE_DEVICE_ID` and
`STRESSWATCH_CORE_DEVICE_ID` in the execution environment. Otherwise the first
connected physical iPhone is used.
