# macOS Finder用ツール

<!-- TOC -->

- [1. インストール](#1-%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB)
- [2. 利用可能なツール](#2-%E5%88%A9%E7%94%A8%E5%8F%AF%E8%83%BD%E3%81%AA%E3%83%84%E3%83%BC%E3%83%AB)
    - [2.1. NewText.app](#21-newtextapp)
    - [2.2. NewTerminal.app](#22-newterminalapp)

<!-- /TOC -->

Finderのツールバーに配置して使用するためのツール群です。以下のようにFinderにTerminalを開くボタンや、空のテキストファイルを作成するボタンを追加できます。

<img src="https://github.com/n-ando/FinderTools/blob/main/figs/findertool_example.png" width=800>

## 1. インストール

インストーラやパッケージは用意していないので git から clone するなどして .app 群をダウンロードしてください。

```shell
$ git clone https://github.com/n-ando/FinderTools
```

つぎに、.app ファイルを /Application または適当な場所にコピーします。

Finderで .app をインストールした場所を開き、Commandキーを押しながら、Finderのツールバーにドラッグ&ドロップして、好きな位置へ配置します。

<img src="https://github.com/n-ando/FinderTools/blob/main/figs/command_drug.png" width=800>


## 2. 利用可能なツール

### 2.1. NewText.app
現在開いているフォルダに空のテキストファイルを作成するボタン。
ファイル名自動では 年(二桁)月日_.txt となる。

### 2.2. NewTerminal.app
現在開いているフォルダをカレントディレクトリとして Terminal アプリを開くボタン。
