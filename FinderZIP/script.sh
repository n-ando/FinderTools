#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

debug=false

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

#------------------------------
# p7zip コマンド対応の処理
#------------------------------
# 圧縮オプションの準備（p7zipが使えるか確認）
# 7zコマンドの存在確認とパス取得
sevenzip=""
if [ -x "/opt/homebrew/bin/7z" ]; then
  sevenzip="/opt/homebrew/bin/7z"
elif [ -x "/usr/local/bin/7z" ]; then
  sevenzip="/usr/local/bin/7z"
fi

# 圧縮選択肢
zip_options=("通常ZIP（パスワードなし）" "暗号化ZIP（パスワード付き）")
if [ -n "$sevenzip" ]; then
  zip_options=("通常ZIP（7z, パスワードなし）" "暗号化ZIP（7z, パスワード付き）")
  zip_options+=("通常7zip（7z, パスワードなし）" "暗号化7zip（7z, パスワード付き）")
fi

osascript_list=$(printf '"%s", ' "${zip_options[@]}")
osascript_list=${osascript_list%, }

choice=$(osascript <<EOF
set options to {${osascript_list}}
choose from list options with prompt "圧縮方法を選んでください：" default items {"通常ZIP（パスワードなし）"} without multiple selections allowed
EOF
)
# キャンセル処理
if [[ "$choice" == "false" || "$choice" == "" ]]; then
  echo "キャンセルされました"
  exit 0
fi
# END of p7zip コマンド対応の処理
#------------------------------


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

# 出力ZIPファイル名をユーザーに入力させる
zip_name=""
if [ ${#files[@]} -eq 1 ] && [ -d "${files[0]}" ]; then
  # 入力が1つだけのディレクトリなら、その名前をデフォルトに
  base_name=$(basename "${files[0]}")
  zip_name=$(osascript <<EOF
display dialog "ZIPファイル名を入力してください（拡張子は不要）:" default answer "${base_name}" buttons {"OK"} default button "OK"
text returned of result
EOF
)
elif [ ${#files[@]} -gt 1 ]; then
  # 複数のファイル/ディレクトリが選択された場合は、空のデフォルト名
  zip_name=$(osascript <<EOF
display dialog "ZIPファイル名を入力してください（拡張子は不要）:" default answer "" buttons {"OK"} default button "OK"
text returned of result
EOF
)
fi

# ZIPファイル名に拡張子をつける
if [ -n "$zip_name" ]; then
  output="$output_dir/${zip_name}.zip"
else
  # 入力が1ファイルかつファイル名指定なし → タイムスタンプ付きにフォールバック
  timestamp=$(date +%Y%m%d_%H%M%S)
  output="$output_dir/Archive_$timestamp.zip"
fi


#------------------------------
# main処理：圧縮処理
#------------------------------
# パスワードが必要な選択肢か？
if [[ "$choice" == *"パスワード付き"* ]]; then
  password=$(osascript <<EOF
display dialog "パスワードを入力してください：" default answer "" with hidden answer
text returned of result
EOF
  )
fi

# 出力ファイル名に応じて拡張子を変える
if [[ "$choice" == *"7zip"* ]]; then
  output="${output%.*}.7z"
else
  output="${output%.*}.zip"
fi


# 圧縮実行
if [[ "$choice" == "通常ZIP（パスワードなし）" ]]; then
  /usr/bin/zip -r "$output" "${relative_files[@]}"

elif [[ "$choice" == "暗号化ZIP（パスワード付き）" ]]; then
  expect <<EOF
spawn /usr/bin/zip -r -e "$output" ${relative_files[@]}
expect "Enter password:"
send "$password\r"
expect "Verify password:"
send "$password\r"
expect eof
EOF

elif [[ "$choice" == "通常ZIP（7z, パスワードなし）" ]]; then
  "$sevenzip" a -tzip "$output" "${relative_files[@]}"

elif [[ "$choice" == "暗号化ZIP（7z, パスワード付き）" ]]; then
  "$sevenzip" a -tzip -p"$password" -mem=ZipCrypto "$output" "${relative_files[@]}"
#  "$sevenzip" a -tzip -p"$password" -mem=AES256 "$output" "${relative_files[@]}"

elif [[ "$choice" == "通常7zip（7z, パスワードなし）" ]]; then
  "$sevenzip" a -t7z "$output" "${relative_files[@]}"

elif [[ "$choice" == "暗号化7zip（7z, パスワード付き）" ]]; then
  "$sevenzip" a -t7z -p"$password" -mhe=on "$output" "${relative_files[@]}"
fi

# 圧縮結果の確認
if [ ! -f "$output" ]; then
  osascript -e 'display dialog "ZIPファイルの作成に失敗しました。" buttons {"OK"}'
  exit 1
fi
