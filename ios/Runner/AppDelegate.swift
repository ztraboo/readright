import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Register a MethodChannel for native audio conversion (WAV -> AAC).
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "readright/audio_converter", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        if call.method == "convertWavToAac" {
          guard let args = call.arguments as? [String: Any],
                let wavPath = args["wavPath"] as? String,
                let aacPath = args["aacPath"] as? String else {
            result(FlutterError(code: "invalid_args", message: "Missing wavPath/aacPath", details: nil))
            return
          }

          let fm = FileManager.default
          let wavURL = URL(fileURLWithPath: wavPath)
          // Diagnostics: ensure the input file exists and log attributes.
          if !fm.fileExists(atPath: wavURL.path) {
            result(FlutterError(code: "input_missing", message: "Input WAV not found at path: \(wavPath)", details: nil))
            return
          }
          do {
            let attrs = try fm.attributesOfItem(atPath: wavURL.path)
            NSLog("readright: convertWavToAac input exists: \(wavURL.path), attrs: \(attrs)")
          } catch {
            NSLog("readright: convertWavToAac could not read attributes for \(wavURL.path): \(error)")
          }

          let asset = AVURLAsset(url: wavURL)
          if let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) {
            NSLog("readright: created AVAssetExportSession, exporting to temp .m4a")
            exportSession.outputFileType = .m4a
            // Export to a temporary .m4a file, then move it to the requested
            // output path. This handles callers that pass an ".aac" extension
            // while AVAssetExportSession expects an .m4a output file type.
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
            exportSession.outputURL = tempURL
            exportSession.exportAsynchronously {
              DispatchQueue.main.async {
                NSLog("readright: export status: \(exportSession.status.rawValue)")
                if exportSession.status == .completed {
                  // Attempt to move the temp file to the requested destination.
                  let destURL = URL(fileURLWithPath: aacPath)
                  do {
                    let fm = FileManager.default
                    if fm.fileExists(atPath: destURL.path) {
                      try fm.removeItem(at: destURL)
                    }
                    try fm.moveItem(at: tempURL, to: destURL)
                    result(true)
                  } catch {
                    // If moving fails, surface the error to Dart for easier debugging.
                    NSLog("readright: move failed: \(error.localizedDescription)")
                    result(FlutterError(code: "move_failed", message: error.localizedDescription, details: nil))
                  }
                } else {
                  let err = exportSession.error?.localizedDescription ?? "export failed"
                  // Include underlying error info if available.
                  if let underlying = exportSession.error as NSError? {
                    NSLog("readright: export failed with error: \(underlying), userInfo: \(String(describing: underlying.userInfo))")
                  } else {
                    NSLog("readright: export failed: \(err)")
                  }
                  result(FlutterError(code: "export_failed", message: err, details: nil))
                }
              }
            }
          } else {
            result(FlutterError(code: "no_session", message: "Cannot create export session", details: nil))
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
