#!/bin/bash
echo "Installing Python dependencies..."
pip install -r requirements.txt || { echo "Issue installing python requirements"; exit 1; }

echo "Generating cmu_map.dart from cmu_words.txt..."
python scripts/generate_cmu_map.py || { echo "Issue generating cmu_map.dart"; exit 1; }

echo "Phoneme map generated successfully."

chmod +x scripts/setup_cmu.sh