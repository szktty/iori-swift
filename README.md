# Iori

[![GitHub tag](https://img.shields.io/github/tag/szktty/iori-swift.svg)](https://github.com/szktty/iori-swift)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

WebRTC シグナリングサーバー Ayame の Swift 実装です。 [OpenAyame/ayame-spec](https://github.com/OpenAyame/ayame-spec) に従い、 [OpenAyame/ayame](https://github.com/OpenAyame/ayame) とできるだけ互換性を保っています。
ただし、勉強がてら実装したものなのでいろいろと不十分な機能があると思います。ご注意ください。

なお、本プロジェクトは株式会社時雨堂の提供ではありません。株式会社時雨堂への問い合わせはしないようにお願いします。

## 特徴

- Ayame とほぼ同じログを出力します
- Ayame と同じ設定ファイルを扱えます
- iOS と macOSでライブラリとして使えます。iOS 端末をAyameサーバーとして動かせます

## Ayame との違い

- 設定ファイルに次の項目を追加しています
  - `iori_debug`: Iori 用のデバッグログ出力の可否
  - `iori_signaling_debug`: シグナリングのデバッグログ出力の可否
- コネクション ID は UUIDv4 の数値を [Clockwork Base32](https://github.com/szktty/swift-clockwork-base32) でエンコードしています

## 未実装の機能

- 最新のログを保持する期限
- 古いログの圧縮
- ウェブフック認証
- ウェブフック払い出し

## 開発予定

- サーバー部分を Vapor で実装し直す

## システム条件

- Xcode 12 以降
  - コマンドラインツールのインストールが必要です
- Swift 5.3 以降
- macOS 11.2 以降
- iOS 14.4 以降

## ビルド

`make` を実行してください。 `iori` コマンドが生成されます。

```
$ make
```

## 使い方

- 設定ファイル `ayame.yaml` を用意します。 `ayame.yaml.example` をコピーすると簡単です。
- `iori` コマンドを実行します。

  ```
  $ ./iori
  ```

## ライブラリとして使う

SwiftPM に対応しています。

### Xcode プロジェクトで使う場合

Swift パッケージのリポジトリに `https://github.com/szktty/iori-swift.git` を指定して追加します。

### `Package.swift` で指定する場合

次のコードを `Package.swift` の `dependencies` に追加してください。

```
.package(
    name: "Iori",
    url: "https://github.com/szktty/iori-swift.git",
    .upToNextMajor(from: "2021.1.0"))
```

## サンプル

`Samples` 以下にあります。

- IoriServerSample: iOS, macOS 端末を Ayame サーバーとして動かすサンプルです。

## ライセンス

Apache License 2.0

```
Copyright 2021 SUZUKI Tetsuya (szktty)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
