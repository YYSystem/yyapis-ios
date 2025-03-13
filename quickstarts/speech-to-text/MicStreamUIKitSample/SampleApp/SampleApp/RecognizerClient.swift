//
//  RecognizerClient.swift
//  SampleApp
//
//  Created by Scorbunny on 2025/03/12.
//

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import os


enum RecognizerEvent {
  case onData(String, Bool)
  case onError(String)
}

enum RecognizerError: Error, LocalizedError {
  case configurationFailed(String)
  case initializationFailed(String)
  case recognitionCanceled(String)
  case requestFailed(String)
  case unknown(String)
  var errorDescription: String? {
    switch self {
    case .configurationFailed(let message):
      return "Configuration failed: \(message)"
    case .initializationFailed(let message):
      return "Initialization failed: \(message)"
    case .recognitionCanceled(let message):
      return "Recognition canceled: \(message)"
    case .requestFailed(let message):
      return "Request failed: \(message)"
    case .unknown(let message):
      return "Unknown error: \(message)"
    }
  }
}

class RecognizerClient {
  private var continuation: AsyncThrowingStream<RecognizerEvent, Error>.Continuation?
  private var requestStream: AsyncStream<Yysystem_StreamRequest>?
  private var requestContinuation: AsyncStream<Yysystem_StreamRequest>.Continuation?
  private let logger = Logger(subsystem: "com.example.SampleApp", category: "RecognizerClient")
  init() {
    logger.info("RecognizerClient initialized.")
  }
  func stream() async throws -> AsyncThrowingStream<RecognizerEvent, Error> {
    let (requestStream, requestContinuation) = AsyncStream<Yysystem_StreamRequest>.makeStream()
    self.requestStream = requestStream
    self.requestContinuation = requestContinuation
    requestContinuation.onTermination = { @Sendable [weak self] _ in
      self?.logger.info("RequestContinuation terminated.")
    }
    let (stream, continuation) = AsyncThrowingStream<RecognizerEvent, Error>.makeStream()
    self.continuation = continuation
    continuation.onTermination = { @Sendable [weak self] _ in
      self?.logger.info("Continuation terminated.")
      self?.requestContinuation?.finish()
    }
    Task {
      do {
        try await withGRPCClient(
          transport: .http2NIOPosix(
            target: .dns(host: "api-grpc-2.yysystem2021.com", port: 443),
            transportSecurity: .tls(.defaults())
          )
        ) { channel in
          logger.info("channel created")
          let client = Yysystem_YYSpeech.Client(wrapping: channel)
          guard let apiKey = ProcessInfo.processInfo.environment["API_KEY"] else {
            continuation.finish(throwing: RecognizerError.configurationFailed("API_KEY is missing"))
            return
          }
          var metadata = Metadata()
          metadata.addString(apiKey, forKey: "yyapis-api-key")
          logger.info("metadate: \(metadata.description)")
          do {
            try await client.recognizeStream(metadata: metadata) { call in
              self.logger.info("call created")
              try await call.write(.with {
                $0.streamingConfig = Yysystem_StreamingConfig.with {
                  $0.model = 10
                  $0.enableInterimResults = true
                  $0.languageCode = 4
                  $0.sampleRateHertz = 16000
                  $0.audioChannelCount = 1
                  $0.encoding = "LINEAR16"
                }
              })
              do {
                for try await request in requestStream {
                  try await call.write(request)
                }
              } catch {
                self.logger.error("\(error.localizedDescription)")
                continuation.finish(throwing: RecognizerError.requestFailed(error.localizedDescription))
              }
            } onResponse: { response in
              do {
                for try await chunk in response.messages {
                  if (chunk.hasResult) {
                    let result = chunk.result
                    let isFinal = result.isFinal
                    let text = result.transcript
                    if !text.isEmpty {
                      continuation.yield(.onData(text, isFinal))
                    }
                  }
                }
              } catch {
                self.logger.error("error: \(error)")
                continuation.finish(throwing: RecognizerError.recognitionCanceled(error.localizedDescription))
              }
            }
          } catch {
            logger.error("error: \(error)")
            continuation.finish(throwing: RecognizerError.initializationFailed(error.localizedDescription))
          }
        }
      } catch {
        logger.info("error: \(error)")
        continuation.finish(throwing: RecognizerError.configurationFailed(error.localizedDescription))
      }
    }
    return stream
  }
  func write(_ request: Yysystem_StreamRequest) async throws {
    guard let continuation = requestContinuation else {
      logger.info("skip write, requestContinuation is nil")
      return
    }
    continuation.yield(request)
  }
  func stop() {
    self.continuation?.finish()
  }
}
