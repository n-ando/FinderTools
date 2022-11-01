# macOS Finder用ツール

Finderのツールバーに配置して使用するためのツール群です。以下のようにFinderにTerminalを開くボタンや、空のテキストファイルを作成するボタンを追加できます。

<img src="https://github.com/n-ando/FinderTools/blob/main/figs/findertool_example.png" width=800>

## インストール

インストーラやパッケージは用意していないので git から clone するなどして .app 群をダウンロードしてください。

```shell
$ git clone https://github.com/n-ando/FinderTools
```

つぎに、.app ファイルを /Application または適当な場所にコピーします。

Finderで .app をインストールした場所を開き、Commandキーを押しながら、Finderのツールバーにドラッグ&ドロップして、好きな位置へ配置します。

<img src="https://github.com/n-ando/FinderTools/blob/main/figs/command_drug.png" width=800>


# 利用可能なツール

## NewText.app
現在開いているフォルダに空のテキストファイルを作成するボタン。
ファイル名自動では 年(二桁)月日_.txt となる。

## NewTerminal.app
現在開いているフォルダをカレントディレクトリとして Terminal アプリを開くボタン。
