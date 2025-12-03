"""Generate a short test WAV for voice_changer manual tests.

Run from repository backend folder:
    py services\tests\generate_test_wav.py
"""
from pathlib import Path
import numpy as np
import wave

p = Path(__file__).resolve().parent.parent / 'recordings' / 'audio'
p.mkdir(parents=True, exist_ok=True)
out = p / 'test_input.wav'

sr = 44100
freq = 440.0
length_s = 1.0

t = np.linspace(0, length_s, int(sr*length_s), endpoint=False)
amp = 0.5 * (2**15-1)
samples = (amp * np.sin(2*np.pi*freq*t)).astype(np.int16)
with wave.open(str(out),'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes(samples.tobytes())

print('Wrote', out)
