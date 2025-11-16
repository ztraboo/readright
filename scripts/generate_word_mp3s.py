import csv
import os
from pathlib import Path
from io import BytesIO

from elevenlabs import ElevenLabs
from pydub import AudioSegment

# IMPORTANT: This script requires ffmpeg to be installed on your system
# for pydub to process audio files.
# On macOS, you can install it via Homebrew:
#   brew install ffmpeg
# On Ubuntu/Debian:
#   sudo apt install ffmpeg
# On Windows:
# If you use Chocolatey package manager, you can install ffmpeg via:
#   choco install ffmpeg -y

# Script to generate MP3 audio files for words using ElevenLabs TTS API.
# Reads words from a CSV file and saves audio files to a specified directory.
# Before running, ensure you have the ELEVENLABS_API_KEY set in your environment.
# Usage: python generate_word_mp3.py
# Requirements: elevenlabs, pydub (pip install elevenlabs pydub)
# https://elevenlabs.io/docs/api-reference/text-to-speech/convert-text-to-speech
# ------------------------------------------------------------------------------


# ---------- Paths & Configuration ----------

# Directory of this script (./scripts)
BASE_DIR = Path(__file__).resolve().parent

# Path to your CSV: ../data/seed_words.csv relative to this script
CSV_PATH = (BASE_DIR / "../data/seed_words.csv").resolve()

# Output directory: ../assets/audio/words relative to ./scripts
OUTPUT_DIR = (BASE_DIR / "../assets/audio/words").resolve()

# ElevenLabs settings
API_KEY = os.getenv("ELEVENLABS_API_KEY")

VOICE_ID = "GvswFWTd71hi9q17e2su"
MODEL_ID = "eleven_multilingual_v2"
OUTPUT_FORMAT = "mp3_44100_192"   # MP3, 44.1kHz, 192 kbps

# language_code: leave None for eleven_multilingual_v2; set "en" if you switch to a model that supports it
LANGUAGE_CODE = None  # e.g. "en"

# Voice settings from your instructions
VOICE_SETTINGS = {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0,
    "use_speaker_boost": True,
    "speed": 1,
}

# Target loudness in dBFS for normalization (tweak to taste: -20.0, -18.0, etc.)
TARGET_DBFS = -20.0


def check_config():
    if not API_KEY:
        raise RuntimeError(
            "ELEVENLABS_API_KEY not set. "
            "Set it in your environment before running this script."
        )
    if not CSV_PATH.exists():
        raise RuntimeError(f"CSV file not found at: {CSV_PATH}")


def get_client() -> ElevenLabs:
    # You can also pass api_key via ElevenLabs(api_key="..."), but env var is standard.
    client = ElevenLabs(
        base_url="https://api.elevenlabs.io",
        api_key=API_KEY,
    )
    return client


def audio_result_to_bytes(audio_result) -> bytes:
    """
    Ensure we end up with a single bytes object from whatever the SDK returns.
    Handles:
      - raw bytes / bytearray
      - iterables of chunks (bytes / str / other)
    """
    if isinstance(audio_result, (bytes, bytearray)):
        return bytes(audio_result)

    chunks = bytearray()
    for chunk in audio_result:
        if chunk is None:
            continue
        if isinstance(chunk, (bytes, bytearray)):
            chunks.extend(chunk)
        elif isinstance(chunk, str):
            chunks.extend(chunk.encode("utf-8"))
        else:
            try:
                chunks.extend(bytes(chunk))
            except Exception:
                print(f"Warning: skipping non-bytes chunk of type {type(chunk)}")
                continue
    return bytes(chunks)


def normalize_mp3_bytes(audio_bytes: bytes, target_dbfs: float = TARGET_DBFS) -> bytes:
    """
    Use pydub to normalize MP3 loudness to a target dBFS.
    Requires ffmpeg to be installed on the system.
    """
    if not audio_bytes:
        return audio_bytes

    audio = AudioSegment.from_file(BytesIO(audio_bytes), format="mp3")
    # audio.dBFS is average loudness; shift it to target_dbfs
    change_in_dBFS = target_dbfs - audio.dBFS
    normalized = audio.apply_gain(change_in_dBFS)

    out_buf = BytesIO()
    normalized.export(out_buf, format="mp3", bitrate="192k")  # matches OUTPUT_FORMAT
    return out_buf.getvalue()


def synthesize_word(client: ElevenLabs, word: str, output_path: Path):
    """
    Use ElevenLabs Python SDK to synthesize a single word to an MP3 file,
    then normalize loudness with pydub before saving.
    """
    print(f"Generating audio for word: {word!r} -> {output_path.name}")

    kwargs = {
        "voice_id": VOICE_ID,
        "output_format": OUTPUT_FORMAT,
        "text": word,
        "model_id": MODEL_ID,
        "previous_text": "Let's pronounce the word",
        "voice_settings": VOICE_SETTINGS,
    }

    if LANGUAGE_CODE:
        kwargs["language_code"] = LANGUAGE_CODE

    audio_result = client.text_to_speech.convert(**kwargs)

    # Collapse to bytes, normalize, then write
    raw_bytes = audio_result_to_bytes(audio_result)
    normalized_bytes = normalize_mp3_bytes(raw_bytes, TARGET_DBFS)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("wb") as f:
        f.write(normalized_bytes)


def main():
    check_config()
    client = get_client()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    words_seen = set()

    with open(CSV_PATH, newline="", encoding="utf-8") as csvfile:
        reader = csv.DictReader(csvfile)

        if "Word" not in reader.fieldnames:
            raise RuntimeError(
                f"'Word' column not found in CSV. Found columns: {reader.fieldnames}"
            )

        for row in reader:
            raw_word = (row.get("Word") or "").strip()
            if not raw_word:
                continue

            if raw_word in words_seen:
                continue
            words_seen.add(raw_word)

            filename = f"{raw_word.lower()}.mp3"
            output_path = OUTPUT_DIR / filename

            try:
                synthesize_word(client, raw_word, output_path)
            except Exception as e:
                print(f"Error synthesizing {raw_word!r}: {e}")

    print(f"Done. Generated {len(words_seen)} audio file(s) in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
