# MicStreamUIKitSample

YYAPIs の音声認識サービスを呼び出して、マイクストリーミング音声入力を音声認識する Swift UIKit サンプルアプリです。

## 事前準備

- [XCode](https://developer.apple.com/xcode/): 16 以降推奨
- [swift-protobuf](https://github.com/apple/swift-protobuf): Protocol Buffers を Swift で扱うために必要
- [grpc-swift](https://github.com/grpc/grpc-swift): gRPC を Swift で扱うために必要
- YYAPIs 音声認識サービスの API キーと proto ファイル(`yysystem.proto`): YYAPIs 音声認識サービスの呼び出しに必要

swift-protobuf や grpc-swift を Homebrew でインストールする場合、以下のコマンドを実行します:

```bash
brew install swift-protobuf grpc-swift
```

API キーと proto ファイルを取得するには、[YYAPIs 開発者コンソール](https://api-web.yysystem2021.com) のアカウントが必要です。
開発者コンソールの詳しい使い方については、こちらの[ドキュメント](https://github.com/YYSystem/yyapis-docs/wiki/DeveloperConsole)を参考にしてください。

## セットアップ

yyapis-ios リポジトリをクローンします:

```bash
git clone https://github.com/YYSystem/yyapis-ios.git
```

このサンプルアプリのディレクトリに移動します:

```bash
cd yyapis-ios/quickstarts/speech-to-text/MicStreamUIKitSample
```

事前準備で取得した proto ファイルを `SampleApp/SampleApp/Protos` ディレクトリにコピーします。

```bash
quickstarts/speech-to-text/MicStreamUIKitSample/SampleApp/SampleApp/Protos/yysystem.proto
```

API キーと proto ファイル。

`proto-gen.sh` を実行して proto ファイルから 2 つの Swift ファイル **yysystem.grpc.swift** と **yysystem.pb.swift** を生成します:

```bash
./proto-gen.sh
```

## サンプルアプリの実行

Xcode でサンプルコードのプロジェクト `SampleApp.xcodeproj` を開きます:

前のステップで生成した 2 つの swift ファイル (`yysystem.grpc.swift` と `yysystem.pb.swift`）が XCode 上に表示されているか確認します。

表示されていない場合、次の操作で 2 つのファイルをプロジェクトに追加します:

**File** > **Add files to "SampleApp"...** > **SampleApp/SampleApp/Protos/yysystem.grpc.swift** と **SampleApp/SampleApp/Protos/yysystem.pb.swift** を選択 > **Add**

Product > Scheme > Edit Scheme... > Run > Arguments > Environment Variables に以下の環境変数を追加します:

| Name    | Value                                                     |
| ------- | --------------------------------------------------------- |
| API_KEY | 事前準備で取得した YYAPIs 音声認識サービスの API キーの値 |

プロジェクトをビルドしてサンプルアプリを実機で実行します。

右上の録音アイコンをタップすると、録音アイコンが停止アイコンになり、音声認識が実行されます。（最初の音声認識が開始されるまで数秒かかります。）
停止アイコンをタップすると、音声認識が終了します。
