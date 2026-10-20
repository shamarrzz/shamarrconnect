on run {daemon_file, agent_file, user}

  -- Remove launchd files left by builds that used the default com.carriez prefix
  -- (split so correct_app_name only rewrites the app name part).
  set legacy to "com.car" & "riez.RustDesk"
  set sh0 to "launchctl unload -w /Library/LaunchDaemons/" & legacy & "_service.plist 2>/dev/null; launchctl bootout gui/$(id -u " & quoted form of user & ")/" & legacy & "_server 2>/dev/null; rm -f /Library/LaunchDaemons/" & legacy & "_service.plist /Library/LaunchAgents/" & legacy & "_server.plist; mkdir -p /var/root/Library/Preferences/com.carriez.RustDesk;"

  set sh1 to "echo " & quoted form of daemon_file & " > /Library/LaunchDaemons/com.carriez.RustDesk_service.plist && chown root:wheel /Library/LaunchDaemons/com.carriez.RustDesk_service.plist;"

  set sh2 to "echo " & quoted form of agent_file & " > /Library/LaunchAgents/com.carriez.RustDesk_server.plist && chown root:wheel /Library/LaunchAgents/com.carriez.RustDesk_server.plist;"

  set sh3 to "cp -rf /Users/" & user & "/Library/Preferences/com.carriez.RustDesk/RustDesk.toml /var/root/Library/Preferences/com.carriez.RustDesk/;"

  set sh4 to "cp -rf /Users/" & user & "/Library/Preferences/com.carriez.RustDesk/RustDesk2.toml /var/root/Library/Preferences/com.carriez.RustDesk/;"

  set sh5 to "launchctl load -w /Library/LaunchDaemons/com.carriez.RustDesk_service.plist;"

  set sh to sh0 & sh1 & sh2 & sh3 & sh4 & sh5

  do shell script sh with prompt "RustDesk wants to install daemon and agent" with administrator privileges
end run
