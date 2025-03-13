//
//  AudioController.swift
//  SampleApp
//
//  Created by Scorbunny on 2023/12/18.
//

import Foundation
import AVFoundation
import os

protocol AudioControllerDelegate {
  func processSampleData(_ data:Data) -> Void
}

class AudioController {
  var remoteIOUnit: AudioComponentInstance? // optional to allow it to be an inout argument
  var delegate : AudioControllerDelegate!
  private var logger = Logger(subsystem: "com.example.SampleApp", category: "AudioController")
  
  static var shared = AudioController()
  
  deinit {
    AudioComponentInstanceDispose(remoteIOUnit!);
  }
  
  func requestRecordPermission () async throws {
    //  https://developer.apple.com/documentation/avfaudio/avaudioapplication/4144305-requestrecordpermission
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .undetermined:
        logger.info("Permission has not been requested yet")
        if await AVAudioApplication.requestRecordPermission() {
          logger.info("Permission is granted")
        } else {
          logger.warning("Permission is denied")
          throw NSError(domain: "PermissionError", code: -1, userInfo: ["message": "Record Permission has been denied"])
        }
        break
      case .denied:
        logger.warning("Permission has been denied")
        throw NSError(domain: "PermissionError", code: -1, userInfo: ["message": "Record Permission has been denied"])
      case .granted:
        logger.info("Permission is already granted")
        break;
      default:
        break
      }
    } else {
      var isGranted = true
      switch AVAudioSession.sharedInstance().recordPermission {
      case .undetermined:
        logger.info("Permission has not been requested yet")
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          if granted {
            self.logger.info("Permission is granted")
          } else {
            self.logger.warning("Permission is denied")
            isGranted = false
          }
        }
        break
      case .denied:
        logger.warning("Permission has been denied")
        isGranted = false
        break
      case .granted:
        logger.info("Permission is already granted")
        break
      default:
        break
      }
      if !isGranted {
        throw NSError(domain: "PermissionError", code: -1, userInfo: ["message": "Record Permission has been denied"])
      }
    }
  }
  
  
  func prepare(specifiedSampleRate: Int) -> OSStatus {
    logger.info("prepare start")
    
    var status = noErr
    
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(AVAudioSession.Category.record)
      try session.setPreferredIOBufferDuration(10)
    } catch {
      return -1
    }
    
    var sampleRate = session.sampleRate
    logger.info("hardware sample rate = \(sampleRate), using specified rate = \(specifiedSampleRate)")
    sampleRate = Double(specifiedSampleRate)
    
    // Describe the RemoteIO unit
    var audioComponentDescription = AudioComponentDescription()
    audioComponentDescription.componentType = kAudioUnitType_Output;
    audioComponentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    audioComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioComponentDescription.componentFlags = 0;
    audioComponentDescription.componentFlagsMask = 0;
    
    // Get the RemoteIO unit
    let remoteIOComponent = AudioComponentFindNext(nil, &audioComponentDescription)
    status = AudioComponentInstanceNew(remoteIOComponent!, &remoteIOUnit)
    if (status != noErr) {
      return status
    }
    
    let bus1 : AudioUnitElement = 1
    var oneFlag : UInt32 = 1
    
    // Configure the RemoteIO unit for input
    status = AudioUnitSetProperty(remoteIOUnit!,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  bus1,
                                  &oneFlag,
                                  UInt32(MemoryLayout<UInt32>.size));
    if (status != noErr) {
      return status
    }
    
    // Set format for mic input (bus 1) on RemoteIO's output scope
    var asbd = AudioStreamBasicDescription()
    asbd.mSampleRate = sampleRate
    asbd.mFormatID = kAudioFormatLinearPCM
    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
    asbd.mBytesPerPacket = 2
    asbd.mFramesPerPacket = 1
    asbd.mBytesPerFrame = 2
    asbd.mChannelsPerFrame = 1
    asbd.mBitsPerChannel = 16
    status = AudioUnitSetProperty(remoteIOUnit!,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  bus1,
                                  &asbd,
                                  UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
    if (status != noErr) {
      return status
    }
    
    // Set the recording callback
    var callbackStruct = AURenderCallbackStruct()
    callbackStruct.inputProc = recordingCallback
    callbackStruct.inputProcRefCon = nil
    status = AudioUnitSetProperty(remoteIOUnit!,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  bus1,
                                  &callbackStruct,
                                  UInt32(MemoryLayout<AURenderCallbackStruct>.size));
    if (status != noErr) {
      return status
    }
    
    logger.info("prepare end")
    // Initialize the RemoteIO unit
    return AudioUnitInitialize(remoteIOUnit!)
  }
  
  func start() -> OSStatus {
    logger.info("recorder start")
    guard let remoteIOUnit = remoteIOUnit else { return noErr }
    return AudioOutputUnitStart(remoteIOUnit)
  }
  
  func stop() -> OSStatus {
    guard let remoteIOUnit = remoteIOUnit else { return noErr }
    logger.info("recorder stop")
    return AudioOutputUnitStop(remoteIOUnit)
  }
}

func recordingCallback(
  inRefCon:UnsafeMutableRawPointer,
  ioActionFlags:UnsafeMutablePointer<AudioUnitRenderActionFlags>,
  inTimeStamp:UnsafePointer<AudioTimeStamp>,
  inBusNumber:UInt32,
  inNumberFrames:UInt32,
  ioData:UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    var status = noErr
    let channelCount : UInt32 = 1
    
    let dataByteSize = inNumberFrames * 2
    let dataPointer = malloc(Int(dataByteSize))
    defer {
      free(dataPointer)
    }
    let buffer = AudioBuffer(mNumberChannels: channelCount, mDataByteSize: dataByteSize, mData: dataPointer)
    var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
    
    // get the recorded samples
    status = withUnsafeMutablePointer(to: &bufferList) { bufferListPtr in
      return AudioUnitRender(AudioController.shared.remoteIOUnit!,
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             UnsafeMutablePointer<AudioBufferList>(bufferListPtr))
    }
    if (status != noErr) {
      return status;
    }
    let data = Data(bytes:  bufferList.mBuffers.mData!, count: Int(bufferList.mBuffers.mDataByteSize))
    DispatchQueue.main.async {
      AudioController.shared.delegate.processSampleData(data)
    }
    return noErr
  }

