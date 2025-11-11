package com.example.readright

import android.media.*
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
	private val CHANNEL = "readright/audio_converter"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			if (call.method == "convertWavToAac") {
				val args = call.arguments as? Map<String, Any>
				val wavPath = args?.get("wavPath") as? String
				val aacPath = args?.get("aacPath") as? String
				val sampleRate = (args?.get("sampleRate") as? Int) ?: 16000
				val bitrateK = (args?.get("bitrateK") as? Int) ?: 64

				if (wavPath == null || aacPath == null) {
					result.error("invalid_args", "Missing wavPath or aacPath", null)
					return@setMethodCallHandler
				}

				try {
					val ok = convertWavToAac(wavPath, aacPath, sampleRate, bitrateK)
					if (ok) result.success(true) else result.error("convert_failed", "Conversion failed", null)
				} catch (e: Exception) {
					result.error("exception", e.message, null)
				}
			} else {
				result.notImplemented()
			}
		}
	}

	private fun convertWavToAac(wavPath: String, aacPath: String, sampleRate: Int, bitrateK: Int): Boolean {
		// Very small WAV parser: assumes PCM 16-bit little endian and 44-byte header
		val wavFile = File(wavPath)
		if (!wavFile.exists()) return false

		val channelCount = 1 // our WAVs are mono in this app

		val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
		val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channelCount)
		format.setInteger(MediaFormat.KEY_BIT_RATE, bitrateK * 1000)
		format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
		// Optional: set max input size
		format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)

		codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
		codec.start()

		val muxer = MediaMuxer(aacPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

		val inputBuffer = ByteArray(2048)
		val fis = FileInputStream(wavFile)
		try {
			// skip WAV header (44 bytes)
			fis.skip(44)

			var sawInputEOS = false
			var sawOutputEOS = false
			var trackIndex = -1

			val bufferInfo = MediaCodec.BufferInfo()

			while (!sawOutputEOS) {
				if (!sawInputEOS) {
					val inputBufIndex = codec.dequeueInputBuffer(10000)
					if (inputBufIndex >= 0) {
						val inputBuf = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) codec.getInputBuffer(inputBufIndex) else ByteBuffer.wrap(ByteArray(0))
						val read = fis.read(inputBuffer)
						if (read <= 0) {
							codec.queueInputBuffer(inputBufIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
							sawInputEOS = true
						} else {
							inputBuf?.clear()
							inputBuf?.put(inputBuffer, 0, read)
							codec.queueInputBuffer(inputBufIndex, 0, read, System.nanoTime() / 1000, 0)
						}
					}
				}

				var outIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
				while (outIndex >= 0) {
					val encodedData = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) codec.getOutputBuffer(outIndex) else ByteBuffer.wrap(ByteArray(0))
					encodedData?.position(bufferInfo.offset)
					encodedData?.limit(bufferInfo.offset + bufferInfo.size)

					if (bufferInfo.size != 0) {
						if (trackIndex == -1) {
							val outputFormat = codec.outputFormat
							trackIndex = muxer.addTrack(outputFormat)
							muxer.start()
						}
						muxer.writeSampleData(trackIndex, encodedData!!, bufferInfo)
					}

					if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
						sawOutputEOS = true
						break
					}
					codec.releaseOutputBuffer(outIndex, false)
					outIndex = codec.dequeueOutputBuffer(bufferInfo, 0)
				}
			}

			return true
		} finally {
			try { fis.close() } catch (ignored: Exception) {}
			try { codec.stop(); codec.release() } catch (ignored: Exception) {}
			try { muxer.stop(); muxer.release() } catch (ignored: Exception) {}
		}
	}
}
