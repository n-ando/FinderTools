#/bin/bash

debug=true

# Finderから渡されたファイルをすべて受け取る
args=("$@")

code_candidates=(
  "/usr/bin/code"
  "/usr/local/bin/code"
  "/opt/homebrew/bin/code"
  "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
)

code_cmd=""
code_list=""

# 順に確認して、最初に見つかった実行可能ファイルを使う
for path in "${code_candidates[@]}"; do
    code_list="${code_list}\n${path}"
  if [ -x "$path" ]; then
    code_cmd="$path"
    break
  fi
done

if [ -z "$code_cmd" ]; then
    if $debug ;  then
        osascript <<EOF
        display dialog "codeコマンドが見つかりません。\nVS-Codeをインストールするか、codeコマンドを以下のいずれかにインストールしてください。\n${code_list}" buttons {"OK"} default button "OK"
EOF
    exit 1
    fi
fi

"$code_cmd" --new-window "${args[@]}"