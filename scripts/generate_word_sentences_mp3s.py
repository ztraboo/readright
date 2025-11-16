import csv
import os
import re
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


# Generate MP3 files for each sentence in data/seed_words.csv.
# Output files placed under PROJECT_ROOT/assets/audio/sentences/ with names like:
#   word_sentence_1.mp3
#   word_sentence_2.mp3
#   word_sentence_3.mp3
#
# Usage: python generate_word_sentences_mp3s.py

BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent
CSV_PATH = (BASE_DIR / "../data/seed_words.csv").resolve()
OUTPUT_DIR = (REPO_ROOT / "assets" / "audio" / "sentences").resolve()

API_KEY = os.getenv("ELEVENLABS_API_KEY")
VOICE_ID = "GvswFWTd71hi9q17e2su"
MODEL_ID = "eleven_multilingual_v2"
OUTPUT_FORMAT = "mp3_44100_192"

VOICE_SETTINGS = {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0,
    "use_speaker_boost": True,
    "speed": 1,
}

# Target loudness in dBFS for normalization (adjust to taste: -20.0, -18.0, etc.)
TARGET_DBFS = -20.0


def check_config():
    if not API_KEY:
        raise RuntimeError("ELEVENLABS_API_KEY not set in environment")
    if not CSV_PATH.exists():
        raise RuntimeError(f"CSV not found at {CSV_PATH}")


def sanitize_filename(s: str) -> str:
    # lowercase, replace spaces and non-word chars with underscore
    s = s.strip().lower()
    s = re.sub(r"\s+", "_", s)
    s = re.sub(r"[^a-z0-9_\-]", "", s)
    if not s:
        s = "untitled"
    return s


def get_client() -> ElevenLabs:
    return ElevenLabs(base_url="https://api.elevenlabs.io", api_key=API_KEY)


def audio_result_to_bytes(audio_result) -> bytes:
    """
    Ensure we end up with a single bytes object from whatever the SDK returns.
    Handles:
      - raw bytes / bytearray
      - iterables of chunks (bytes / str / other)
    """
    if isinstance(audio_result, (bytes, bytearray)):
        return bytes(audio_result)

    # If it's a generator or other iterable of chunks
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
                print(f"Warning: skipping chunk of type {type(chunk)}")
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
    # audio.dBFS is the average loudness; we shift it to target_dbfs
    change_in_dBFS = target_dbfs - audio.dBFS
    normalized = audio.apply_gain(change_in_dBFS)

    out_buf = BytesIO()
    # Re-export as MP3 at 192 kbps (matches OUTPUT_FORMAT)
    normalized.export(out_buf, format="mp3", bitrate="192k")
    return out_buf.getvalue()


def write_audio_bytes(output_path: Path, audio_result):
    """
    Take the audio_result from ElevenLabs, normalize loudness, and write to disk.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Collapse any streaming/chunked result into a single bytes object
    raw_bytes = audio_result_to_bytes(audio_result)

    # Normalize loudness with pydub
    normalized_bytes = normalize_mp3_bytes(raw_bytes, TARGET_DBFS)

    with output_path.open("wb") as f:
        f.write(normalized_bytes)


def synthesize_sentence(client: ElevenLabs, text: str, out_path: Path):
    kwargs = {
        "voice_id": VOICE_ID,
        "output_format": OUTPUT_FORMAT,
        "text": text,
        "model_id": MODEL_ID,
        "previous_text": "Listen to the sentence",
        "voice_settings": VOICE_SETTINGS,
    }
    audio_result = client.text_to_speech.convert(**kwargs)
    write_audio_bytes(out_path, audio_result)


def main():
    check_config()
    client = get_client()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with CSV_PATH.open(newline="", encoding="utf-8") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            word = (row.get("Word") or "").strip()
            if not word:
                continue
            key = sanitize_filename(word)
            # For each of the three sentence columns, generate an audio file
            for i in range(1, 4):
                col = f"Sentence {i}"
                sentence = (row.get(col) or "").strip()
                if not sentence:
                    continue
                filename = f"{key}_sentence_{i}.mp3"
                out_path = OUTPUT_DIR / filename
                print(f"Synthesizing: {word!r} ({col}) -> {out_path}")
                try:
                    synthesize_sentence(client, sentence, out_path)
                except Exception as e:
                    print(f"Error synthesizing {word} {col}: {e}")

    print("Done")


if __name__ == "__main__":
    main()
