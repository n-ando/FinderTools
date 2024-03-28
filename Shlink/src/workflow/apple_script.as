on run {input, parameters}
    tell application "Finder"
        set selectedItems to selection
    end tell

    if selectedItems is {} then
        display dialog "Finderで圧縮したいファイルを1つ以上選択してから実行してください。" buttons {"OK"} default button "OK" with icon caution with title "Finder Shrink"
        return {}
    end if

    try
        set modeButton to button returned of (display dialog "圧縮プリセットの指定方法を選択してください。" & return & return & "screen: 低画質・最小サイズ" & return & "ebook: 中程度" & return & "printer: 高品質" & return & "prepress: 最高品質" buttons {"キャンセル", "全種類同じ設定", "種類ごとに指定"} default button "全種類同じ設定" cancel button "キャンセル" with title "Finder Shrink")
    on error number -128
        return {}
    end try

    if modeButton is "全種類同じ設定" then
        set commonPreset to my pickPreset("すべての種類に使う圧縮率を選んでください。", "ebook")
        if commonPreset is false then return {}

        set pdfPreset to commonPreset
        set officePreset to commonPreset
        set imagePreset to commonPreset
        set videoPreset to commonPreset
        set zipPreset to commonPreset
    else
        set pdfPreset to my pickPreset("PDFに使う圧縮率を選んでください。", "ebook")
        if pdfPreset is false then return {}

        set officePreset to my pickPreset("Word(docx) / PowerPoint(pptx)に使う圧縮率を選んでください。", "ebook")
        if officePreset is false then return {}

        set imagePreset to my pickPreset("画像ファイルに使う圧縮率を選んでください。", "ebook")
        if imagePreset is false then return {}

        set videoPreset to my pickPreset("動画ファイルに使う圧縮率を選んでください。", "ebook")
        if videoPreset is false then return {}

        set zipPreset to my pickPreset("ZIPファイル自体の出力名に付ける設定名を選んでください。ZIP内の各ファイルは上の種類別設定で圧縮します。", "ebook")
        if zipPreset is false then return {}
    end if

    set outputList to {"__FINDER_SHRINK_V2__", "PDF=" & pdfPreset, "OFFICE=" & officePreset, "IMAGE=" & imagePreset, "VIDEO=" & videoPreset, "ZIP=" & zipPreset}

    repeat with anItem in selectedItems
        try
            set itemAlias to anItem as alias
            set end of outputList to POSIX path of itemAlias
        end try
    end repeat

    return outputList
end run

on pickPreset(promptText, defaultPreset)
    set presets to {"screen", "ebook", "printer", "prepress"}

    try
        set picked to choose from list presets with title "Finder Shrink" with prompt promptText default items {defaultPreset} OK button name "OK" cancel button name "キャンセル"
        if picked is false then return false
        return item 1 of picked
    on error number -128
        return false
    end try
end pickPreset

