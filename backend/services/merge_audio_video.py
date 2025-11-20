#!/usr/bin/env python3
"""
Audio-Video Merger
Menggabungkan file WAV audio dengan MP4 video menjadi satu file MP4 dengan audio track
"""

import os
import subprocess
import sys
from pathlib import Path
import shutil


def merge_audio_video(video_file, audio_file, output_file):
    """
    Merge WAV audio dengan MP4 video menggunakan ffmpeg
    
    Args:
        video_file: Path ke MP4 file (video only)
        audio_file: Path ke WAV file (audio only)
        output_file: Path untuk output file (video + audio)
    
    Returns:
        bool: True jika berhasil, False jika gagal
    """
    
    if not os.path.exists(video_file):
        print(f"✗ Video file not found: {video_file}")
        return False
    
    if not os.path.exists(audio_file):
        print(f"✗ Audio file not found: {audio_file}")
        return False
    
    # Find ffmpeg executable. Try PATH, common locations, and imageio_ffmpeg as a fallback.
    def find_ffmpeg_executable():
        # 1) which/where
        exe = shutil.which('ffmpeg')
        if exe:
            return exe

        # 2) common Windows installs (scoop, chocolatey)
        common_paths = [
            os.path.expandvars(r"%USERPROFILE%\\scoop\\apps\\ffmpeg\\current\\bin\\ffmpeg.exe"),
            r"C:\\ProgramData\\chocolatey\\bin\\ffmpeg.exe",
            r"C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe",
            r"C:\\ffmpeg\\bin\\ffmpeg.exe",
        ]
        for p in common_paths:
            if os.path.exists(p):
                return p

        # 3) Try imageio-ffmpeg (may download or provide a bundled binary)
        try:
            import imageio_ffmpeg
            exe = imageio_ffmpeg.get_ffmpeg_exe()
            if exe and os.path.exists(exe):
                return exe
        except Exception:
            pass

        return None

    ffmpeg_exe = find_ffmpeg_executable()
    if not ffmpeg_exe:
        print("✗ ffmpeg not found. Install it first or install the Python package 'imageio-ffmpeg'.")
        print("  Windows (choco): choco install ffmpeg")
        print("  OR install imageio-ffmpeg: pip install imageio-ffmpeg")
        print("  See: https://ffmpeg.org/download.html")
        return False
    
    # Create output directory if needed
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    try:
        # Use ffmpeg to merge audio and video
        # -i video_file: input video (has video stream)
        # -i audio_file: input audio (has audio stream)
        # -c:v copy: copy video codec (no re-encoding)
        # -c:a aac: encode audio as AAC (MP4 compatible)
        # -shortest: stop at shortest stream
        
        cmd = [
            ffmpeg_exe,
            '-y',  # Overwrite output file without asking
            '-i', video_file,
            '-i', audio_file,
            '-c:v', 'copy',  # Copy video codec (no re-encoding)
            '-c:a', 'aac',   # Encode audio as AAC
            '-shortest',     # Stop at shortest stream
            output_file
        ]
        
        print(f"✓ Merging video and audio...")
        print(f"  Video: {video_file}")
        print(f"  Audio: {audio_file}")
        print(f"  Output: {output_file}")

        result = subprocess.run(cmd,
                                capture_output=True,
                                text=True,
                                timeout=300)

        if result.returncode == 0 and os.path.exists(output_file):
            output_size = os.path.getsize(output_file) / (1024 * 1024)
            print(f"✓ Merge successful: {output_size:.2f} MB")
            return True
        else:
            print(f"✗ Merge failed:")
            if result.stderr:
                # Print last few lines of error
                errors = result.stderr.split('\n')
                for line in errors[-10:]:
                    if line.strip():
                        print(f"  {line}")
            return False

    except subprocess.TimeoutExpired:
        print("✗ Merge timed out (ffmpeg took too long)")
        return False
    except Exception as e:
        print(f"✗ Error during merge: {e}")
        return False


def cleanup_temporary_files(video_file, audio_file, keep_originals=False):
    """
    Hapus file video dan audio terpisah setelah merge
    
    Args:
        video_file: Path ke MP4 file
        audio_file: Path ke WAV file
        keep_originals: Jika True, jangan hapus file asli
    """
    if keep_originals:
        return
    
    try:
        if os.path.exists(video_file):
            os.remove(video_file)
            print(f"✓ Cleaned up video file: {video_file}")
    except Exception as e:
        print(f"⚠️ Failed to delete video file: {e}")
    
    try:
        if os.path.exists(audio_file):
            os.remove(audio_file)
            print(f"✓ Cleaned up audio file: {audio_file}")
    except Exception as e:
        print(f"⚠️ Failed to delete audio file: {e}")


def get_file_info(filepath):
    """Get file size and duration info"""
    if not os.path.exists(filepath):
        return None
    
    try:
        size_mb = os.path.getsize(filepath) / (1024 * 1024)
        return size_mb
    except:
        return None


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python merge_audio_video.py <video_file> <audio_file> [output_file]")
        print("")
        print("Example:")
        print("  python merge_audio_video.py recording.mp4 audio.wav output.mp4")
        sys.exit(1)
    
    video = sys.argv[1]
    audio = sys.argv[2]
    output = sys.argv[3] if len(sys.argv) > 3 else video.replace('.mp4', '_with_audio.mp4')
    
    if merge_audio_video(video, audio, output):
        print("\n✓ Merge completed successfully!")
        sys.exit(0)
    else:
        print("\n✗ Merge failed!")
        sys.exit(1)
