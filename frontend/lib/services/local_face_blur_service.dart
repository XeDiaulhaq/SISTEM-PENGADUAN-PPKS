import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Local Face Blur Service
/// Implements simple face detection and blur using image processing techniques
/// Falls back to simple blur if ML Kit not available
class LocalFaceBlurService {
  /// Detect faces dan blur mereka dalam image
  /// Input: JPEG bytes
  /// Output: JPEG bytes dengan wajah yang di-blur
  Future<Uint8List?> detectAndBlurFaces(Uint8List imageBytes) async {
    try {
      // Decode JPEG ke image
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Resize untuk faster processing
      final resized = img.copyResize(
        image,
        width: image.width > 800 ? 800 : image.width,
        height: image.height > 600 ? 600 : image.height,
      );

      // Simple face detection menggunakan bright area detection
      // Faces biasanya lebih bright (skin tone) dibanding background
      var blurredImage = _detectAndBlurSimple(resized);
      
      // Encode kembali ke JPEG
      final blurredBytes = img.encodeJpg(blurredImage, quality: 85);
      return Uint8List.fromList(blurredBytes);
    } catch (e) {
      print('[LocalBlur] Error: $e');
      return null;
    }
  }

  /// Simple face detection menggunakan brightness dan color analysis
  img.Image _detectAndBlurSimple(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    // Find bright areas (likely to be face/skin)
    // Scan image dan cari regions dengan consistent brightness
    final List<_FaceRegion> regions = [];
    final int blockSize = 40; // 40x40 pixel blocks
    final int threshold = 100; // Brightness threshold
    
    // Scan blocks
    for (int y = 0; y < height - blockSize; y += blockSize ~/ 2) {
      for (int x = 0; x < width - blockSize; x += blockSize ~/ 2) {
        final brightness = _calculateBlockBrightness(image, x, y, blockSize);
        
        // If bright enough, might be face
        if (brightness > threshold) {
          regions.add(_FaceRegion(x, y, blockSize, blockSize));
        }
      }
    }
    
    // Merge overlapping regions
    final mergedRegions = _mergeRegions(regions);
    
    // Blur detected regions
    var result = image.clone();
    for (final region in mergedRegions) {
      result = _blurRegion(
        result,
        region.x,
        region.y,
        region.x + region.width,
        region.y + region.height,
      );
    }
    
    return result;
  }

  /// Calculate average brightness of a block
  int _calculateBlockBrightness(img.Image image, int x, int y, int size) {
    int totalBrightness = 0;
    int pixelCount = 0;
    
    for (int py = y; py < y + size && py < image.height; py++) {
      for (int px = x; px < x + size && px < image.width; px++) {
        final pixel = image.getPixelSafe(px, py);
        // Calculate brightness (Y in YCbCr)
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();
        totalBrightness += brightness;
        pixelCount++;
      }
    }
    
    return pixelCount > 0 ? (totalBrightness ~/ pixelCount) : 0;
  }

  /// Merge overlapping regions
  List<_FaceRegion> _mergeRegions(List<_FaceRegion> regions) {
    if (regions.isEmpty) return [];
    
    final merged = <_FaceRegion>[];
    var currentRegion = regions[0];
    
    for (int i = 1; i < regions.length; i++) {
      final region = regions[i];
      
      // Check if regions overlap or are close
      if (_regionsOverlap(currentRegion, region)) {
        // Merge regions
        currentRegion = _FaceRegion(
          currentRegion.x < region.x ? currentRegion.x : region.x,
          currentRegion.y < region.y ? currentRegion.y : region.y,
          (currentRegion.width + region.width) ~/ 2,
          (currentRegion.height + region.height) ~/ 2,
        );
      } else {
        merged.add(currentRegion);
        currentRegion = region;
      }
    }
    
    merged.add(currentRegion);
    
    // Filter small regions (likely noise)
    return merged.where((r) => r.width > 30 && r.height > 30).toList();
  }

  /// Check if two regions overlap or are close
  bool _regionsOverlap(_FaceRegion r1, _FaceRegion r2) {
    final margin = 40; // Merge regions within 40 pixels
    return !(r1.x + r1.width + margin < r2.x ||
        r2.x + r2.width + margin < r1.x ||
        r1.y + r1.height + margin < r2.y ||
        r2.y + r2.height + margin < r1.y);
  }

  /// Blur region tertentu dalam image
  img.Image _blurRegion(
    img.Image image,
    int x1,
    int y1,
    int x2,
    int y2,
  ) {
    // Clamp coordinates ke image bounds
    final x = (x1).clamp(0, image.width - 1);
    final y = (y1).clamp(0, image.height - 1);
    final width = ((x2 - x1).abs()).clamp(1, image.width - x);
    final height = ((y2 - y1).abs()).clamp(1, image.height - y);

    // Apply Gaussian blur pada region
    final region = img.copyCrop(image, x: x, y: y, width: width, height: height);
    final blurred = img.gaussianBlur(region, radius: 25);
    
    // Paste blurred region kembali ke image
    return img.compositeImage(
      image,
      blurred,
      dstX: x,
      dstY: y,
    );
  }

  void dispose() {
    // Cleanup if needed
  }
}

/// Simple face region class
class _FaceRegion {
  int x;
  int y;
  int width;
  int height;

  _FaceRegion(this.x, this.y, this.width, this.height);
}
