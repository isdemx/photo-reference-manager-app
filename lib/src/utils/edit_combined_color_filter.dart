import 'dart:math' as math;
import 'dart:ui';

/// Комбинируем яркость + насыщенность + контраст + hue
  ColorFilter combinedColorFilter(
    double brightness,
    double saturation,
    double temp,
    double hue,
  ) {
    // 1) Матрица яркости (brightness)
    final b = brightness;
    final brightnessMatrix = [
      b,
      0,
      0,
      0,
      0,
      0,
      b,
      0,
      0,
      0,
      0,
      0,
      b,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    // 2) Матрица насыщенности (saturation)
    final s = saturation;
    const lumR = 0.3086, lumG = 0.6094, lumB = 0.0820;
    final sr = (1 - s) * lumR;
    final sg = (1 - s) * lumG;
    final sb = (1 - s) * lumB;
    final saturationMatrix = [
      sr + s,
      sg,
      sb,
      0,
      0,
      sr,
      sg + s,
      sb,
      0,
      0,
      sr,
      sg,
      sb + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    // 3) Матрица контраста (temperature)
    // Если temp в диапазоне [-1..1],
// то при temp>0 картинка теплеет, при temp<0 – холодеет.

    final temperatureMatrix = [
      // R' = R + 2*temp
      1, 0, 0, 0, 2 * temp,
      // G' = G
      0, 1, 0, 0, 0,
      // B' = B - 2*temp
      0, 0, 1, 0, -2 * temp,
      // A' = A
      0, 0, 0, 1, 0,
    ];

    // 4) Матрица оттенка (hue)
    final cosA = math.cos(hue);
    final sinA = math.sin(hue);
    // Пример поворота матрицы для hue
    final hueMatrix = [
      0.213 + cosA * 0.787 - sinA * 0.213,
      0.715 - cosA * 0.715 - sinA * 0.715,
      0.072 - cosA * 0.072 + sinA * 0.928,
      0,
      0,
      0.213 - cosA * 0.213 + sinA * 0.143,
      0.715 + cosA * 0.285 + sinA * 0.140,
      0.072 - cosA * 0.072 - sinA * 0.283,
      0,
      0,
      0.213 - cosA * 0.213 - sinA * 0.787,
      0.715 - cosA * 0.715 + sinA * 0.715,
      0.072 + cosA * 0.928 + sinA * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    // Функция умножения матриц 4x5
    List<double> multiply(List<double> m1, List<double> m2) {
      final out = List<double>.filled(20, 0.0);
      for (int row = 0; row < 4; row++) {
        for (int col = 0; col < 5; col++) {
          double sum = 0;
          for (int k = 0; k < 4; k++) {
            sum += m1[row * 5 + k] * m2[k * 5 + col];
          }
          // offset
          if (col == 4) {
            sum += m1[row * 5 + 4];
          }
          out[row * 5 + col] = sum;
        }
      }
      return out;
    }

    // Последовательно умножаем: brightness -> saturation -> temp -> hue
    final m1 = multiply(
      brightnessMatrix.map((e) => e.toDouble()).toList(),
      saturationMatrix.map((e) => e.toDouble()).toList(),
    );
    final m2 = multiply(
      m1.map((e) => e.toDouble()).toList(),
      temperatureMatrix.map((e) => e.toDouble()).toList(),
    );
    final m3 = multiply(
      m2.map((e) => e.toDouble()).toList(),
      hueMatrix.map((e) => e.toDouble()).toList(),
    );

    return ColorFilter.matrix(m3);
  }