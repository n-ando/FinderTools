tell application "Finder"
	
	set this_folder to target of front window as alias
	
end tell
return POSIX path of this_folder
