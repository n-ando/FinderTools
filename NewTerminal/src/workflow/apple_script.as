on run {input, parameters}
	
	tell application "Finder"
		set hfsCurrentFolder to insertion location as Unicode text
		set currentFolder to get POSIX path of hfsCurrentFolder
	end tell
	
	set command to "cd \"" & currentFolder & "\""
	
	tell application "Terminal"
		do script command
		activate
	end tell
	
end run
