# macOS Finder用ツール

<!-- TOC -->

- [macOS Finder用ツール](#macos-finder%E7%94%A8%E3%83%84%E3%83%BC%E3%83%AB)
    - [インストール](#%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB)
    - [利用可能なツール](#%E5%88%A9%E7%94%A8%E5%8F%AF%E8%83%BD%E3%81%AA%E3%83%84%E3%83%BC%E3%83%AB)
        - [NewText.app](#newtextapp)
        - [NewMD.app](#newmdapp)
        - [NewTerminal.app](#newterminalapp)
        - [FinderZIP.app](#finderzipapp)
            - [圧縮ファイル名について](#%E5%9C%A7%E7%B8%AE%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E5%90%8D%E3%81%AB%E3%81%A4%E3%81%84%E3%81%A6)
            - [Windowsでの文字化け問題について](#windows%E3%81%A7%E3%81%AE%E6%96%87%E5%AD%97%E5%8C%96%E3%81%91%E5%95%8F%E9%A1%8C%E3%81%AB%E3%81%A4%E3%81%84%E3%81%A6)
            - [ZipCrypto形式, AES256形式](#zipcrypto%E5%BD%A2%E5%BC%8F-aes256%E5%BD%A2%E5%BC%8F)
        - [NewVSCode.app](#newvscodeapp)
        - [AnyToPDF.app](#anytopdfapp)
            - [必要なコマンド](#%E5%BF%85%E8%A6%81%E3%81%AA%E3%82%B3%E3%83%9E%E3%83%B3%E3%83%89)
        - [Shlink.app](#shlinkapp)
            - [画質・品質レベル](#%E7%94%BB%E8%B3%AA%E3%83%BB%E5%93%81%E8%B3%AA%E3%83%AC%E3%83%99%E3%83%AB)

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
<img src="https://github.com/n-ando/FinderTools/blob/main/NewText/src/icon/light/master_1024.png" width=32>

現在開いているフォルダに空のテキストファイルを作成するボタン。
ファイル名は自動で **年(二桁)月日_.txt** となります。

### 2.2. NewMD.app
<img src="https://github.com/n-ando/FinderTools/blob/main/NewMD/src/icon/light/master_1024.png" width=32>

現在開いているフォルダに空のMarkdownファイルを作成するボタン。
ファイル名は自動で **年(二桁)月日_.md** となります。

### 2.3. NewTerminal.app
<img src="https://github.com/n-ando/FinderTools/blob/main/NewTerminal/src/icon/light/master_1024.png" width=32>

現在開いているフォルダをカレントディレクトリとして Terminal アプリを開くボタン。

### 2.4. FinderZIP.app
<img src="https://github.com/n-ando/FinderTools/blob/main/FinderZIP/src/icon/light/master_1024.png" width=32>

選択したファイルをZIPで圧縮するボタン。パスワード付きZIPも作成可能。

#### 圧縮ファイル名について
圧縮ファイルは、現在のディレクトリに、**Archive_<日付>.zip** または **Archive_<日付>_encripted.zip** というファイル名で圧縮ファイルが作成されます。フォルダが1個のみ選択されている場合は、**<フォルダ名>.zip** というファイル名で圧縮ファイルが作成されます。

#### Windowsでの文字化け問題について
デフォルトでは内蔵のzipコマンドもしくは <a href="https://brew.sh/ja/">Homebrew</a> のzipコマンドが使用されますが、これらのコマンドで圧縮したZIPファイルは、Windowsで展開すると文字化けする問題が知られています。
Homebrewで p7zip (7zコマンド) をインストールすることにより、この問題を回避できます。7zコマンドがHomebrewでインストールされていると、7zコマンドが優先的に使用され、ZIP形式、7z形式のいずれかで圧縮ができるようになります。

#### ZipCrypto形式, AES256形式
7zコマンドでZIPファイルを作成すると、デフォルトではWindowsの標準機能では展開できない **AES256形式** で圧縮されます。展開するにはWindows側に<a href="https://7-zip.opensource.jp/">7-Zip</a>等、AES256形式に対応したアプリケーションをインストールする必要があります。
なお、本アプリケーションでは、Windowsでも展開できるように **ZipCrypto形式** で圧縮するようになっていますが、ZipCrypto形式はセキュリティ的に脆弱でパスワードを容易に推定できることが知られており、セキュリティを考慮する必要がファイルの場合は別途直接7zコマンドで圧縮することを推奨します。

### 2.5. NewVSCode.app
<img src="https://github.com/n-ando/FinderTools/blob/main/NewVSCode/src/icon/light/master_1024.png" width=32>

選択したファイルをVS-Codeの新規ウインドウで開くボタン。
既存のウィンドウがどこにあっても、現在のデスクトップ上でVS-Codeを開きます。

### 2.6. AnyToPDF.app
<img src="https://github.com/n-ando/FinderTools/blob/main/AnyToPDF/src/icon/light/master_1024.png" width=32>

選択したファイルをPDFに変換するボタン。
対応ファイルは、
- Wordファイル : {"doc", "docx"}
- PowerPointファイル : {"ppt", "pptx"}
- テキストファイル : {"txt"}
- Markdownファイル : {"md", "markdown"}
- 画像ファイル : {"png", "jpg", "jpeg", "gif", "tif", "tiff", "bmp", "heic", "webp"}

#### 必要なコマンド

- Word: Microsoft Word
- PowerPoint: Microsoft PowerPoint
- Text: cupsfilter (macOS標準)
- Markdown: pandoc, mactex
- 画像ファイル: cupsfilter (macOS標準)

pandoc, mactexについては、以下のコマンドであらかじめインストールしておいてください。

```shell
% brew install mactex pandoc
```

### 2.6. Shlink.app
<img src="https://github.com/n-ando/FinderTools/blob/main/Shlink/src/icon/light/master_1024.png" width=32>

選択したファイルのファイルサイズを縮小するボタン。
以下の Word, PowerPoint, ZIP, PDF, 画像、動画ファイルを縮小することができます。

- Wordファイル : docx
- PowerPointファイル : pptx
- ZIPファイル: zip
- PDFファイル : pdf
- 画像ファイル : jpg, jpeg, png, gif, tif, tiff, bmp, webp, heic, heif, avif, jp2, j2k
- 動画ファイル : mp4, m4v, mov, mkv, avi, webm, wmv, mpg, mpeg, 3gp, 3g2, flv, mts, m2ts, ts 

Word, PowerPoint, ZIPについては、内包する画像ファイルや動画ファイルを縮小してファイルサイズを縮小します。


#### 画質・品質レベル
以下の4段階から、圧縮レベルを選択して、圧縮を行います。

- screen: 低画質・最小サイズ, サイズ:1024, 品質:60
- ebook: 中程度, 画面閲覧用, サイズ:1280, 品質:70
- printer: 高品質, 通常印刷用, サイズ:1920, 品質:80
- prepress: 最高品質, 高品質印刷用, サイズ:2560, 品質:90

サイズは縦横のサイズのうち、そのサイズを超えた場合はリサイズします。
品質は、ImageMagic の品質レベル値です。


