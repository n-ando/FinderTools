# macOS Finder用ツール

<!-- TOC -->

- [macOS Finder用ツール](#macos-finder%E7%94%A8%E3%83%84%E3%83%BC%E3%83%AB)
    - [1. インストール](#1-%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB)
    - [2. 利用可能なツール](#2-%E5%88%A9%E7%94%A8%E5%8F%AF%E8%83%BD%E3%81%AA%E3%83%84%E3%83%BC%E3%83%AB)
        - [2.1. NewText.app](#21-newtextapp)
        - [2.2. NewMD.app](#22-newmdapp)
        - [2.3. NewTerminal.app](#23-newterminalapp)
        - [2.4. FinderZIP.app](#24-finderzipapp)
        - [2.5. NewVSCode.app](#25-newvscodeapp)

<!-- /TOC -->

Finderのツールバーに配置して使用するためのツール群です。以下のようにFinderにTerminalを開くボタンや、空のテキストファイルを作成するボタンを追加できます。

<img src="https://github.com/n-ando/FinderTools/blob/main/figs/findertool_example.png" width=800>

## 1. インストール

インストーラやパッケージは用意していないので git から clone するなどして .app 群をダウンロードしてください。

```shell
$ git clone https://github.com/n-ando/FinderTools
```

なお、appファイルは、アイコンの色によってライトテーマ（通常テーマ）とダークテーマ用に分かれています。
- <アプリ名>_dark.app: ダークテーマ用アプリ
- <アプリ名>_light.app: ライトテーマ用アプリ

つぎに、.app ファイルを /Application または適当な場所にコピーします。使用しているテーマに合わせて、適切なappファイルをコピーしてください。

Finderで .app をインストールした場所を開き、Commandキーを押しながら、Finderのツールバーにドラッグ&ドロップして、好きな位置へ配置します。

<img src="https://github.com/n-ando/FinderTools/blob/main/figs/command_drug.png" width=800>


## 2. 利用可能なツール

### 2.1. NewText.app
<img src="https://github.com/n-ando/FinderTools/blob/main/NewText/icons/icon_512x512@2x_dark.png" width=64>
<img src="https://github.com/n-ando/FinderTools/blob/main/NewText/icons/icon_512x512@2x_light.png" width=64>

現在開いているフォルダに空のテキストファイルを作成するボタン。
ファイル名自動では 年(二桁)月日_.txt となる。

### 2.2. NewMD.app
現在開いているフォルダに空のMarkDownファイルを作成するボタン。
ファイル名自動では 年(二桁)月日_.md となる。

### 2.3. NewTerminal.app
現在開いているフォルダをカレントディレクトリとして Terminal アプリを開くボタン。

### 2.4. FinderZIP.app
選択したファイルをZIPで圧縮するボタン。パスワード付きZIPも作成可能。
圧縮ファイルは、現在のディレクトリに、Archive_<日付>.zip または Archive_<日付>_encripted.zip というファイル名で作成される。

### 2.5. NewVSCode.app
選択したファイルをVS-Codeの新規ウインドウで開くボタン。
既存のウィンドウがどこにあっても、現在のデスクトップ上でVS-Codeを開きます。

