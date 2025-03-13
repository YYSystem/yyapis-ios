//
//  RecognizerViewModel.swift
//  SampleApp
//
//  Created by Scorbunny on 2025/03/12.
//


import Foundation
import Combine
import GRPCCore
import os


@MainActor
class RecognizerViewModel: ObservableObject {
  struct RecognitionResult {
    let text: String
    let isFinal: Bool
  }
  @Published var isRecognizing: Bool = false
  @Published var recognitionResult = RecognitionResult(text: "ここにテキストが表示されます。", isFinal: true)
  @Published var errorText = ""
  private var recognizer: RecognizerClient!
  private let logger = Logger(subsystem: "com.example.SampleApp", category: "RecognizerViewModel")
  init() {
    logger.info("RecognizerViewModel initialized")
    self.recognizer = RecognizerClient()
  }
  func startRecognition() {
    Task(priority: .high) { [weak self] in
      self?.isRecognizing = true
      defer {
        self?.isRecognizing = false
      }
      do {
        if let stream = try await self?.recognizer.stream() {
          for try await event in stream {
            self?.handleEvent(event)
          }
        } else {
          self?.logger.warning("Recognition stream is nil")
        }
      } catch {
        self?.logger.error("Recognition error: \(error.localizedDescription)")
        self?.handleEvent(.onError(error.localizedDescription))
      }
    }
  }
  func write(_ data: Data) async throws {
    try await recognizer.write(.with {
      $0.audiobytes = data
    })
  }
  func stopRecognition() {
    recognizer.stop()
  }
  private func handleEvent(_ event: RecognizerEvent) {
    switch event {
    case .onData(let text, let isFinal):
      logger.info("onData: \(isFinal.description) \(text)")
      self.recognitionResult = RecognitionResult(text: text, isFinal: isFinal)
    case .onError(let errorText):
      logger.error("onError: \(errorText)")
      self.errorText = errorText
    }
  }
}
