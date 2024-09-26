# yyapis-ios-speechtotext-example

Terminal アプリで gitlab からサンプルコードのプロジェクトをクローンする

```bash
git clone -b develop https://yysystem-gitlab.com/yy-admin-developer/yyapis-ios-speechtotext-example.git
```

Homebrew で [swift-protobuf](https://github.com/apple/swift-protobuf) と [grpc-swift](https://github.com/grpc/grpc-swift) をインストールする

```bash
brew install swift-protobuf grpc-swift
```

プロジェクトのルートディレクトリに移動してから、シェルスクリプトを実行して proto ファイルから 2 つの Swift ファイル **yysystem.grpc.swift** と **yysystem.pb.swift** を生成する

```bash
cd yyapis-ios-speechtotext-example
./proto-gen.sh
```

Xcode でサンプルコードのプロジェクトを開く

前のステップで生成した 2 つの swift ファイルをプロジェクトに追加する

**File** > **Add files to "SampleApp"...** > **SampleApp/SampleApp/Protos/yysystem.grpc.swift** と **SampleApp/SampleApp/Protos/yysystem.pb.swift** を選択 > **Add**

SampleApp/SampleApp/ViewController.swift ファイルを開き、次の行を編集して、YYAPIs の API キー を設定する

```swift
let API_KEY = "SET_YOUR_API_KEY"
```

プロジェクトをビルドしてサンプルアプリオを実機で実行する

右下の波形アイコンをクリックして、音声認識を実行する
もう一度クリックして、音声認識を終了する

### Appendix

[swift-protobuf](https://github.com/apple/swift-protobuf)
[grpc-swift](https://github.com/grpc/grpc-swift)
[Google Speech-to-Text sample](https://github.com/GoogleCloudPlatform/ios-docs-samples/tree/master/speech/Swift/Speech-gRPC-Streaming)
