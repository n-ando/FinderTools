property wordExts : {"doc", "docx"}
property pptExts : {"ppt", "pptx"}
property plainTextExts : {"txt"}
property markdownExts : {"md", "markdown"}
property imageExts : {"png", "jpg", "jpeg", "gif", "tif", "tiff", "bmp", "heic", "webp"}

on run {input, parameters}
	set convertedCount to 0
	set failedItems to {}
	set unsupportedItems to {}
	
	tell application "Finder"
		set selectedItems to selection as alias list
	end tell
	
	if selectedItems is {} then
		display dialog "PDFに変換するファイルをFinderで選択してから実行してください。" buttons {"OK"} default button "OK"
		return
	end if
	
	set totalCount to count of selectedItems
	set processedCount to 0
	
	display notification ((totalCount as text) & " 件のファイルをPDFに変換します。") with title "PDF変換開始"
	
	repeat with f in selectedItems
		set processedCount to processedCount + 1
		
		set inPath to POSIX path of f
		set fileName to my fileNameFromPath(inPath)
		set extName to my lowerExt(inPath)
		set outPath to my makeOutputPath(inPath)
		
		display notification "処理中: " & fileName with title "PDF変換中" subtitle ((processedCount as text) & " / " & (totalCount as text))
		
		try
			if wordExts contains extName then
				my removeExistingFile(outPath)
				my convertWordToPDF(inPath, outPath)
				set convertedCount to convertedCount + 1
				
			else if pptExts contains extName then
				my removeExistingFile(outPath)
				my convertPowerPointToPDF(inPath, outPath)
				set convertedCount to convertedCount + 1
				
			else if markdownExts contains extName then
				my removeExistingFile(outPath)
				my convertMarkdownByPandoc(inPath, outPath)
				set convertedCount to convertedCount + 1
				
			else if plainTextExts contains extName then
				my removeExistingFile(outPath)
				my convertByCupsFilter(inPath, outPath)
				set convertedCount to convertedCount + 1
				
			else if imageExts contains extName then
				my removeExistingFile(outPath)
				my convertByCupsFilter(inPath, outPath)
				set convertedCount to convertedCount + 1
				
			else
				set end of unsupportedItems to inPath
			end if
			
		on error errMsg number errNum
			set end of failedItems to inPath & " : " & errMsg
			display notification fileName with title "PDF変換失敗" subtitle errMsg
		end try
	end repeat
	
	set msg to (convertedCount as text) & " 件のファイルをPDFに変換しました。"
	
	if unsupportedItems is not {} then
		set msg to msg & return & return & "未対応のファイル:" & return & my joinList(unsupportedItems, return)
	end if
	
	if failedItems is not {} then
		set msg to msg & return & return & "変換に失敗したファイル:" & return & my joinList(failedItems, return)
	end if
	
	if failedItems is {} then
		display notification msg with title "PDF変換完了"
	else
		display notification ((convertedCount as text) & " 件成功、" & ((count of failedItems) as text) & " 件失敗しました。") with title "PDF変換完了"
	end if
	
	display dialog msg buttons {"OK"} default button "OK"
	
	return input
end run


on convertWordToPDF(inPath, outPath)
	tell application "Microsoft Word"
		activate
		open POSIX file inPath
		
		delay 2
		
		save as active document file name outPath file format format PDF
		close active document saving no
	end tell
end convertWordToPDF


on convertPowerPointToPDF(inPath, outPath)
	tell application "Microsoft PowerPoint"
		activate
		open POSIX file inPath
		
		delay 1
		
		save active presentation in POSIX file outPath as save as PDF
		close active presentation
	end tell
end convertPowerPointToPDF


on convertMarkdownByPandoc(inPath, outPath)
	set pandocPath to my findExecutable("pandoc")
	set latexPath to my findExecutable("lualatex")
	
	set cmd to quoted form of pandocPath & " " & quoted form of inPath & " -o " & quoted form of outPath & " --pdf-engine=" & quoted form of latexPath & " -V documentclass=ltjsarticle -V geometry:margin=25mm"
	
	do shell script cmd
end convertMarkdownByPandoc


on convertByCupsFilter(inPath, outPath)
	do shell script "/usr/sbin/cupsfilter -m application/pdf " & quoted form of inPath & " > " & quoted form of outPath
end convertByCupsFilter


on removeExistingFile(outPath)
	do shell script "/bin/rm -f " & quoted form of outPath
end removeExistingFile


on findExecutable(commandName)
	set candidatePaths to {¬
		"/opt/homebrew/bin/" & commandName, ¬
		"/usr/local/bin/" & commandName, ¬
		"/Library/TeX/texbin/" & commandName, ¬
		"/usr/bin/" & commandName, ¬
		"/bin/" & commandName}
	
	repeat with p in candidatePaths
		if my executableExists(p as text) then
			return p as text
		end if
	end repeat
	
	try
		set foundPath to do shell script "/usr/bin/env PATH=/opt/homebrew/bin:/usr/local/bin:/Library/TeX/texbin:/usr/bin:/bin:/usr/sbin:/sbin /usr/bin/which " & quoted form of commandName
		if foundPath is not "" then
			return foundPath
		end if
	on error
		error commandName & " が見つかりません。インストールされているか確認してください。"
	end try
	
	error commandName & " が見つかりません。インストールされているか確認してください。"
end findExecutable


on executableExists(posixPath)
	try
		do shell script "/bin/test -x " & quoted form of posixPath
		return true
	on error
		return false
	end try
end executableExists


on lowerExt(posixPath)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "."
	set parts to text items of posixPath
	
	if (count of parts) < 2 then
		set AppleScript's text item delimiters to oldDelims
		return ""
	end if
	
	set extName to item -1 of parts
	set AppleScript's text item delimiters to oldDelims
	
	return do shell script "/usr/bin/printf %s " & quoted form of extName & " | /usr/bin/tr '[:upper:]' '[:lower:]'"
end lowerExt


on makeOutputPath(posixPath)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "."
	set parts to text items of posixPath
	
	if (count of parts) < 2 then
		set AppleScript's text item delimiters to oldDelims
		return posixPath & ".pdf"
	end if
	
	set stemParts to items 1 thru -2 of parts
	set AppleScript's text item delimiters to "."
	set stemPath to stemParts as text
	set AppleScript's text item delimiters to oldDelims
	
	return stemPath & ".pdf"
end makeOutputPath


on fileNameFromPath(posixPath)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "/"
	set parts to text items of posixPath
	
	if parts is {} then
		set AppleScript's text item delimiters to oldDelims
		return posixPath
	end if
	
	set fileName to item -1 of parts
	set AppleScript's text item delimiters to oldDelims
	return fileName
end fileNameFromPath


on joinList(theList, delimiter)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to delimiter
	set joinedText to theList as text
	set AppleScript's text item delimiters to oldDelims
	return joinedText
end joinList
