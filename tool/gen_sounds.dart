// Генератор 8-bit звуковых эффектов «Литр До Дома».
//
// Ассеты не скачиваются: все сэмплы синтезируются кодом (квадрат, шум,
// огибающие) и сохраняются в assets/audio/*.wav как PCM 16-bit mono.
// Запуск: dart tool/gen_sounds.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _sampleRate = 22050;
const String _outDir = 'assets/audio';

void main() {
  Directory(_outDir).createSync(recursive: true);
  _write('ui', _ui());
  _write('coin', _coin());
  _write('full', _full());
  _write('horn', _horn());
  _write('crash', _crash());
  _write('event', _event());
  _write('win', _win());
  _write('lose', _lose());
  _write('siren', _siren());
  _write('low', _low());
  _write('engine', _engine());
  _write('pump', _pump());
  stdout.writeln('Готово: $_outDir');
}

Float64List _buffer(double seconds) => Float64List((seconds * _sampleRate).round());

double _square(double phase) => (phase - phase.floorToDouble()) < 0.5 ? 1.0 : -1.0;

/// Простая мелодия из нот: каждая длится [seg] секунд с затуханием.
Float64List _arpeggio(List<double> notes, double dur, double decay, double amp) {
  final Float64List b = _buffer(dur);
  final double seg = dur / notes.length;
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final int idx = (t / seg).floor().clamp(0, notes.length - 1);
    final double tau = t - idx * seg;
    phase += notes[idx] / _sampleRate;
    b[i] = _square(phase) * exp(-tau * decay).toDouble() * amp;
  }
  return b;
}

Float64List _ui() {
  const double dur = 0.07;
  final Float64List b = _buffer(dur);
  const double f0 = 720;
  const double f1 = 1120;
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double p = t / dur;
    phase += (f0 + (f1 - f0) * p) / _sampleRate;
    b[i] = _square(phase) * pow(1 - p, 1.5).toDouble() * 0.3;
  }
  return b;
}

Float64List _coin() {
  const double dur = 0.18;
  final Float64List b = _buffer(dur);
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double f = t < 0.07 ? 1046.5 : 1568.0;
    final double tau = t < 0.07 ? t : t - 0.07;
    phase += f / _sampleRate;
    b[i] = _square(phase) * exp(-tau * 16).toDouble() * 0.32;
  }
  return b;
}

Float64List _full() => _arpeggio(<double>[659.25, 880.0, 1046.5, 1318.5], 0.45, 7, 0.34);

Float64List _horn() {
  const double dur = 0.4;
  final Float64List b = _buffer(dur);
  double p1 = 0;
  double p2 = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    p1 += 420 / _sampleRate;
    p2 += 530 / _sampleRate;
    final double env = min(1.0, t * 40) * exp(-t * 4).toDouble();
    b[i] = (_square(p1) * 0.5 + _square(p2) * 0.5) * env * 0.38;
  }
  return b;
}

Float64List _crash() {
  const double dur = 0.35;
  final Float64List b = _buffer(dur);
  final Random rng = Random(41);
  double lp = 0;
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    phase += 120 / _sampleRate;
    final double noise = rng.nextDouble() * 2 - 1;
    lp += (noise - lp) * 0.4;
    final double env = exp(-t * 11).toDouble();
    b[i] = (lp * 0.8 + _square(phase) * 0.3) * env * 0.5;
  }
  return b;
}

Float64List _event() {
  const double dur = 0.22;
  final Float64List b = _buffer(dur);
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double f = t < 0.09 ? 880.0 : 1320.0;
    final double tau = t < 0.09 ? t : t - 0.09;
    phase += f / _sampleRate;
    b[i] = _square(phase) * exp(-tau * 20).toDouble() * 0.3;
  }
  return b;
}

Float64List _win() => _arpeggio(<double>[523.25, 659.25, 783.99, 1046.5, 1318.5], 0.75, 5, 0.34);

Float64List _lose() => _arpeggio(<double>[523.25, 415.30, 329.63, 261.63, 196.00], 0.9, 4, 0.34);

Float64List _siren() {
  const double dur = 0.7;
  final Float64List b = _buffer(dur);
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double f = 520 + 260 * sin(2 * pi * 2 * t);
    phase += f / _sampleRate;
    final double env = min(1.0, t * 20) * min(1.0, (dur - t) * 8);
    b[i] = _square(phase) * env * 0.3;
  }
  return b;
}

Float64List _low() {
  const double dur = 0.32;
  final Float64List b = _buffer(dur);
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double f = t < 0.14 ? 330.0 : 247.0;
    final double tau = t < 0.14 ? t : t - 0.14;
    phase += f / _sampleRate;
    b[i] = _square(phase) * exp(-tau * 11).toDouble() * 0.34;
  }
  return b;
}

/// Двигатель — зацикленный низкий рокот (целое число периодов на 1 секунду).
Float64List _engine() {
  const double dur = 1.0;
  final Float64List b = _buffer(dur);
  final Random rng = Random(53);
  double p1 = 0;
  double p2 = 0;
  double lp = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    p1 += 80 / _sampleRate;
    p2 += 160 / _sampleRate;
    final double noise = rng.nextDouble() * 2 - 1;
    lp += (noise - lp) * 0.05;
    final double wobble = 0.85 + 0.15 * sin(2 * pi * 80 * t);
    b[i] = (_square(p1) * 0.55 + _square(p2) * 0.25 + lp * 0.2) * wobble * 0.34;
  }
  return b;
}

/// Колонка — зацикленные «щелчки» (8 в секунду).
Float64List _pump() {
  const double dur = 1.0;
  final Float64List b = _buffer(dur);
  final Random rng = Random(67);
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double click = t * 8;
    final double tau = click - click.floorToDouble();
    phase += 60 / _sampleRate;
    final double noise = rng.nextDouble() * 2 - 1;
    final double env = exp(-tau * 26).toDouble();
    b[i] = (noise * 0.6 + _square(phase) * 0.4) * env * 0.28;
  }
  return b;
}

void _write(String name, Float64List samples) {
  final int dataLen = samples.length * 2;
  final ByteData data = ByteData(44 + dataLen);

  void ascii(int offset, String tag) {
    for (int i = 0; i < tag.length; i++) {
      data.setUint8(offset + i, tag.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataLen, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, _sampleRate, Endian.little);
  data.setUint32(28, _sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, dataLen, Endian.little);

  for (int i = 0; i < samples.length; i++) {
    double s = samples[i];
    if (s > 1) {
      s = 1;
    } else if (s < -1) {
      s = -1;
    }
    data.setInt16(44 + i * 2, (s * 32767).round(), Endian.little);
  }

  final File file = File('$_outDir/$name.wav');
  file.writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln('  $name.wav (${dataLen + 44} байт)');
}
