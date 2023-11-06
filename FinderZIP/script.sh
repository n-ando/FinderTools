#!/bin/bash

debug=true

# Finderの現在のフォルダパスを取得
output_dir=$(osascript <<EOF
tell application "Finder"
  set thePath to (POSIX path of (target of front window as alias))
end tell
EOF
)

# Debug diralog
if $debug ;  then
  osascript <<EOF
display dialog "出力ディレクトリ:${output_dir}" buttons {"OK"} default button "OK"
EOF
fi

# 選択されたファイルの一覧、空・不可視文字要素は削除
files=()
for arg in "$@"; do
  trimmed="$(echo "$arg" | tr -d '[:space:]')"
  if [ -n "$trimmed" ] && [ -e "$arg" ]; then
    files+=("$arg")
  fi
done

# Debug diralog
if $debug ;  then
  file_list=$(printf "%s\n" "${files[@]}")
  osascript <<EOF
display dialog "ファイルリスト(引数):${file_list}" buttons {"OK"} default button "OK"
EOF
fi

# 入力チェック：ファイルリストが空ならエラー
if [ ${#files[@]} -eq 0 ]; then
  osascript -e 'display dialog "ファイルが選択されていません。" buttons {"OK"}'
  exit 1
fi

# カレントディレクトリを出力ディレクトリにセット
cd "$output_dir" || exit 1

# ファイル：ファイルパスをカレントからの相対パスにする
relative_files=()
for f in "${files[@]}"; do
  rel_path=$(python3 -c "import os.path; print(os.path.relpath('$f', '$output_dir'))")
  if [ -e "$rel_path" ]; then
    relative_files+=("$rel_path")
  else
    echo "スキップ: $rel_path は見つかりません"
  fi
done

# Debug diralog
if $debug ;  then
  file_list=$(printf "%s\n" "${relative_files[@]}")
  osascript <<EOF
display dialog "ファイルリスト(相対パス):${file_list}" buttons {"OK"} default button "OK"
EOF
fi

# 出力ファイル名を定義
timestamp=$(date +%Y%m%d_%H%M%S)
output="$output_dir/Archive_$timestamp.zip"

# 圧縮方法を選択
choice=$(osascript <<EOF
set options to {"暗号化ZIP（パスワード付き）", "通常ZIP（パスワードなし）"}
choose from list options with prompt "圧縮方法を選んでください：" default items {"通常ZIP（パスワードなし）"} without multiple selections allowed
EOF
)

# キャンセル処理
echo "$choice" > "$output_dir/hogehoge.txt"
if [[ "$choice" == "false" || "$choice" == "" ]]; then
  echo "キャンセルされました"
  exit 0
fi

# 圧縮処理
if [[ "$choice" == *"パスワード付き"* ]]; then
  password=$(osascript <<EOF
display dialog "パスワードを入力してください：" default answer "" with hidden answer
text returned of result
EOF
  )
  output="$output_dir/Archive_${timestamp}_encrypted.zip"
  printf "%s\n" "${files[@]}" >> "$output_dir/hogehoge.txt"
  expect <<EOF
spawn /usr/bin/zip -r -e "$output" ${relative_files[@]}
expect "Enter password:"
send "$password\r"
expect "Verify password:"
send "$password\r"
expect eof
EOF
else
  printf "%s\n" "${file_list}" > "/tmp/hogehoge.txt"
  /usr/bin/zip -r "$output" "${relative_files[@]}"
fi

# 圧縮結果の確認
if [ ! -f "$output" ]; then
  osascript -e 'display dialog "ZIPファイルの作成に失敗しました。" buttons {"OK"}'
  exit 1
fi
