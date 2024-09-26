//
//  YyStreamRecognizer.swift
//  SampleApp
//
//  Created by Scorbunny on 2023/12/20.
//

import Foundation
import GRPC
import GRPCCore
import NIOCore
import NIOPosix

final class YyStreamRecognizer {
  private var group: EventLoopGroup?
  private var channel: GRPCChannel?
  private var call: GRPCAsyncBidirectionalStreamingCall<Yysystem_StreamRequest, Yysystem_StreamResponse>?
  private var client: Yysystem_YYSpeechAsyncClient?
  private var streaming: Bool = false
  var onData: (_ chunk: Yysystem_StreamResponse) -> Void = { chunk in
    if (chunk.hasError) {
      let error = chunk.error
      print("onData: chunk has error \(error)")
      // 立て直しが必要
      return
    }
    print("onData: \(chunk.result.transcript)")
    return
  }
  var onError: (_ error: Error) -> Void = { error in
    if let grpcError = error as? GRPCStatus {
      print("onError(GRPCStatus): \(grpcError)")
    } else {
      print("onError: \(error)")
    }
  }
  var port = 443
  var address = "api-grpc-2.yysystem2021.com"
  var apiKey = ""
  var ssl = true
  
  static let shared = YyStreamRecognizer()
  private init () {}
  func send(_ audioData: Data, streamingConfig: Yysystem_StreamingConfig? = nil) async throws {
    if (!streaming) {
      streaming = true
      print("address: \(address), port: \(port), ssl: \(ssl), apiKey: \(apiKey)")
      let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
      self.group = group
      let channel = try GRPCChannelPool.with(target: .host(address, port: port), transportSecurity: ssl ? .tls(GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL()) : .plaintext, eventLoopGroup: group)
      self.channel = channel
      let client = Yysystem_YYSpeechAsyncClient(channel: channel)
      self.client = client
      var callOptions = CallOptions()
      callOptions.customMetadata.add(contentsOf: [("yyapis-api-key", apiKey)])
      let call = client.makeRecognizeStreamCall(callOptions: callOptions)
      self.call = call
      Task {
        do {
          for try await chunk in call.responseStream {
            onData(chunk)
          }
        } catch {
          if isStreaming() {
            onError(error)
          }
        }
      }
      if let streamingConfig = streamingConfig {
        try await call.requestStream.send(.with {
          $0.streamingConfig = streamingConfig
        })
      }
    }
    try await call?.requestStream.send(.with {
      $0.audiobytes = audioData as Data
    })
  }
  func stop() throws {
    if !streaming {
      print("Recognizer has not started yet")
      return
    }
    streaming = false
    try shutdown()
  }
  func isStreaming() -> Bool {
    return streaming
  }
  func shutdown () throws {
    call?.requestStream.finish()
    try channel?.close().wait()
    try group?.syncShutdownGracefully()
  }
  deinit {
    print("deinit")
    do {
      try shutdown()
    } catch {
      print("Fail to deinit, \(error)")
    }
  }
}
