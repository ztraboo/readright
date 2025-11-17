import subprocess
import sys
import os

try:
    import nltk
except ImportError:
    print("installing NLTK...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "nltk"])
    import nltk
    print("NLTK installed successfully.")
    exit (1)

nltk.download('cmudict')
from nltk.corpus import cmudict

d = cmudict.dict()

# Get path to cmu_words.txt
script_dir = os.path.dirname(os.path.abspath(__file__))
readright_root = os.path.abspath(os.path.join(script_dir, '..'))
cmu_words_path = os.path.join(readright_root, 'data', 'cmu_words.txt')
with open(cmu_words_path) as f:
    words = [line.strip().split('\t')[0].lower() for line in f]

# write out to dart map
# Get path to cmu_words.txt
script_dir = os.path.dirname(os.path.abspath(__file__))
readright_root = os.path.abspath(os.path.join(script_dir, '..'))  # adjust '..' as needed
cmu_map_path = os.path.join(readright_root, 'lib', 'audio', 'stt', 'on_device', 'cmu_map.dart')
# readright\lib\audio\stt\on_device\cmu_map.dart
with open(cmu_map_path, 'w') as out:
    out.write('final Map<String, List<String>> cmuDict = {\n')
    for word in words:
        if word in d:
            phonemes = d[word][0]
            phoneme_str = ', '.join(f"'{p}'" for p in phonemes)
            safe_word = word.replace("'", "\\'")
            out.write(f"  '{safe_word}': [{phoneme_str}],\n")

    out.write('};\n')



def load_cmu_words():
    nltk.download('cmudict')
    # Load the CMU Pronouncing Dictionary
    d = cmudict.dict()

    # Get path to cmu_words.txt
    script_dir = os.path.dirname(os.path.abspath(__file__))
    readright_root = os.path.abspath(os.path.join(script_dir, '..'))  # adjust '..' as needed
    output_path = os.path.join(readright_root, 'data', 'cmu_words.txt')


    # Write each word and its phoneme sequence
    with open(output_path, 'w') as f:
        for word in sorted(d.keys()):
            phonemes = ' '.join(d[word][0])
            f.write(f"{word}\t{phonemes}\n")

    print(f"Saved {len(d)} words with phonemes to {output_path}")