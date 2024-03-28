# Finder Shrink Automator

Finderで選択したPDF、docx、pptx、画像、動画、ZIPを、Automatorアプリから圧縮するための2アクション構成です。

## 依存コマンド

Homebrewがある場合:

```bash
brew install ghostscript imagemagick ffmpeg
```

macOS標準の`zip`/`unzip`も使用します。

## Automatorでの作り方

1. Automatorを開き、「アプリケーション」を新規作成します。
2. 「AppleScriptを実行」を追加し、`FinderShrink_AppleScript.applescript`の内容を貼り付けます。
3. その下に「シェルスクリプトを実行」を追加します。
4. シェルを`/bin/bash`、入力の引き渡しを「引数として」にします。
5. `FinderShrink_RunShellScript.sh`の内容を貼り付けます。
6. `Finder Shrink.app`などの名前で保存します。
7. 保存したアプリをFinderのツールバーへCommandキーを押しながらドラッグします。

## 出力

- 通常ファイル: `filename_screen.pdf` のように、元ファイルの横に出力します。
- ZIP: `archive_screen.zip`のように新規ZIPを作成し、ZIP内部の対象ファイルも順次圧縮します。
- docx/pptx: Officeファイル内部の`word/media`または`ppt/media`の画像・動画を圧縮して再ZIP化します。
- 圧縮後の方が大きい場合は、出力を作成せずログに`SKIP`を記録します。

## ログ

ログは以下に保存されます。

```text
~/Library/Logs/FinderShrink/
```
