import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'battery_life.dart';
import 'diagnostic.dart';
import 'tools.dart';

/// Suite complète de tests matériel, façon « Phone Doctor ».
class HardwareTestsHub extends StatelessWidget {
  const HardwareTestsHub({super.key});

  @override
  Widget build(BuildContext context) {
    final android = Native.isAndroid;
    final tests = <(IconData, String, String, Widget)>[
      if (android) (Icons.volume_up, 'Haut-parleurs', 'Gauche / droite / stéréo / balayage', const SpeakerTest()),
      if (android) (Icons.mic, 'Microphone', 'Niveau d’entrée en direct', const MicTest()),
      if (android) (Icons.battery_charging_full, 'Autonomie batterie', 'Consommation réelle, autonomie, usure', const BatteryLifeTest()),
      (Icons.vibration, 'Vibreur', 'Intensités et motifs', const VibratorTest()),
      (Icons.flashlight_on, 'Lampe (flash)', 'Allumage du flash arrière', const FlashTest()),
      (Icons.photo_camera, 'Caméras', 'Avant et arrière, aperçu en direct', const CameraTest()),
      (Icons.touch_app, 'Écran tactile', 'Zones mortes et multipoint', const TouchTest()),
      (Icons.palette, 'Écran — pixels', 'Couleurs plein écran', const ScreenTest()),
      if (android) (Icons.radio_button_checked, 'Boutons physiques', 'Volume +/− et caméra', const ButtonsTest()),
      (Icons.sensors, 'Proximité & lumière', 'Capteurs interactifs', const ProximityLightTest()),
      (Icons.explore, 'Boussole & gyroscope', 'Capteurs de mouvement en direct', const SensorsLink()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Tests matériel')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (icon, title, sub, page) = tests[i];
          return NxCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: NxColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
            ),
          );
        },
      ),
    );
  }
}

/// Renvoie vers la liste des capteurs en direct (définie dans diagnostic.dart via Tools).
class SensorsLink extends StatelessWidget {
  const SensorsLink({super.key});

  @override
  Widget build(BuildContext context) {
    // Réutilise l'écran capteurs existant.
    return const _SensorsRedirect();
  }
}

class _SensorsRedirect extends StatefulWidget {
  const _SensorsRedirect();

  @override
  State<_SensorsRedirect> createState() => _SensorsRedirectState();
}

class _SensorsRedirectState extends State<_SensorsRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SensorsScreen()));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class SpeakerTest extends StatefulWidget {
  const SpeakerTest({super.key});

  @override
  State<SpeakerTest> createState() => _SpeakerTestState();
}

class _SpeakerTestState extends State<SpeakerTest> {
  String? _playing;

  Future<void> _play(String id, {String channel = 'both', bool sweep = false, double freq = 1000}) async {
    setState(() => _playing = id);
    await Native.playTone(channel: channel, sweep: sweep, freq: freq, ms: sweep ? 4000 : 1500);
    if (mounted) {
      await Future.delayed(Duration(milliseconds: sweep ? 4000 : 1500));
      if (mounted && _playing == id) setState(() => _playing = null);
    }
  }

  @override
  void dispose() {
    Native.stopTone();
    super.dispose();
  }

  Widget _btn(String id, String label, IconData icon, {String channel = 'both', bool sweep = false, double freq = 1000}) {
    final active = _playing == id;
    return FilledButton.tonalIcon(
      style: active ? FilledButton.styleFrom(backgroundColor: NxColors.primary) : null,
      onPressed: () => _play(id, channel: channel, sweep: sweep, freq: freq),
      icon: Icon(icon),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Haut-parleurs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Text(
              'Monte le volume, puis lance chaque test. Tu dois entendre le son venir du bon côté. '
              'Le balayage (grave → aigu) révèle un haut-parleur qui grésille ou coupe.',
              style: TextStyle(color: NxColors.muted, fontSize: 13),
            ),
          ),
          const SectionHeader('Canaux'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _btn('left', 'Gauche', Icons.arrow_back, channel: 'left'),
            _btn('right', 'Droite', Icons.arrow_forward, channel: 'right'),
            _btn('both', 'Stéréo', Icons.surround_sound, channel: 'both'),
          ]),
          const SectionHeader('Tonalités'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _btn('low', '200 Hz (grave)', Icons.graphic_eq, freq: 200),
            _btn('mid', '1 kHz', Icons.graphic_eq, freq: 1000),
            _btn('high', '10 kHz (aigu)', Icons.graphic_eq, freq: 10000),
            _btn('sweep', 'Balayage', Icons.waves, sweep: true),
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Native.stopTone();
              setState(() => _playing = null);
            },
            icon: const Icon(Icons.stop),
            label: const Text('Arrêter'),
          ),
        ],
      ),
    );
  }
}

class MicTest extends StatefulWidget {
  const MicTest({super.key});

  @override
  State<MicTest> createState() => _MicTestState();
}

class _MicTestState extends State<MicTest> {
  StreamSubscription<List<double>>? _sub;
  double _rms = 0;
  double _peak = 0;
  double _maxSeen = 0;
  final _history = <double>[];
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Native.requestPermission('mic');
    await Future.delayed(const Duration(milliseconds: 400));
    _sub = Native.micStream().listen((v) {
      if (!mounted) return;
      setState(() {
        _rms = v.isNotEmpty ? v[0] : 0;
        _peak = v.length > 1 ? v[1] : 0;
        if (_peak > _maxSeen) _maxSeen = _peak;
        _history.add(_rms);
        if (_history.length > 80) _history.removeAt(0);
      });
    }, onError: (_) {
      if (mounted) setState(() => _denied = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Microphone')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_denied ? 'Autorise le micro pour ce test.' : 'Parle, souffle ou tape près du micro : la barre doit réagir.',
                  style: TextStyle(color: NxColors.muted, fontSize: 13)),
              const SizedBox(height: 16),
              const Text('Niveau d’entrée'),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _rms.clamp(0, 1),
                  minHeight: 20,
                  color: _rms > 0.6 ? NxColors.bad : _rms > 0.25 ? NxColors.warn : NxColors.ok,
                  backgroundColor: NxColors.surfaceHigh,
                ),
              ),
              const SizedBox(height: 10),
              Text('RMS ${(_rms * 100).toStringAsFixed(0)} % · crête ${(_peak * 100).toStringAsFixed(0)} % · max vu ${(_maxSeen * 100).toStringAsFixed(0)} %',
                  style: TextStyle(fontSize: 12, color: NxColors.muted)),
              if (_denied) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Native.openSettings('android.settings.APPLICATION_DETAILS_SETTINGS', package: 'com.heiphaistos.nitroid'), child: const Text('Ouvrir les permissions')),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          if (_history.length > 2) NxCard(child: Sparkline(_history, color: NxColors.ok, height: 60)),
          Padding(
            padding: EdgeInsets.all(8),
            child: Text('Si la barre reste à zéro alors que tu parles, le micro est peut-être défectueux ou bloqué par un étui.',
                style: TextStyle(fontSize: 12, color: NxColors.muted)),
          ),
        ],
      ),
    );
  }
}

class VibratorTest extends StatelessWidget {
  const VibratorTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vibreur')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Text('Chaque bouton déclenche une vibration différente. Si rien ne se passe, le moteur de vibration est peut-être HS.',
                style: TextStyle(color: NxColors.muted, fontSize: 13)),
          ),
          const SectionHeader('Intensité'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton(onPressed: () => Native.vibrate(60, amplitude: 60), child: const Text('Léger')),
            OutlinedButton(onPressed: () => Native.vibrate(200, amplitude: 150), child: const Text('Moyen')),
            OutlinedButton(onPressed: () => Native.vibrate(400, amplitude: 255), child: const Text('Fort')),
            OutlinedButton(onPressed: () => Native.vibrate(1500, amplitude: 255), child: const Text('Long')),
          ]),
          const SectionHeader('Motifs'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton(
              onPressed: () async {
                for (var i = 0; i < 3; i++) {
                  await Native.vibrate(120, amplitude: 255);
                  await Future.delayed(const Duration(milliseconds: 220));
                }
              },
              child: const Text('Triple'),
            ),
            OutlinedButton(
              onPressed: () async {
                for (final ms in [80, 160, 240, 320]) {
                  await Native.vibrate(ms, amplitude: 255);
                  await Future.delayed(Duration(milliseconds: ms + 120));
                }
              },
              child: const Text('Crescendo'),
            ),
          ]),
        ],
      ),
    );
  }
}

class FlashTest extends StatefulWidget {
  const FlashTest({super.key});

  @override
  State<FlashTest> createState() => _FlashTestState();
}

class _FlashTestState extends State<FlashTest> {
  bool _on = false;

  @override
  void dispose() {
    if (_on) Native.torch(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lampe (flash)')),
      body: Center(
        child: GestureDetector(
          onTap: () async {
            final ok = await Native.torch(!_on);
            if (ok) {
              setState(() => _on = !_on);
            } else if (context.mounted) {
              showSnack(context, 'Flash indisponible');
            }
          },
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _on ? NxColors.accent : NxColors.surface,
              boxShadow: _on ? [BoxShadow(color: NxColors.accent.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 8)] : null,
              border: Border.all(color: NxColors.accent, width: 2),
            ),
            child: Icon(_on ? Icons.flashlight_on : Icons.flashlight_off, size: 64, color: _on ? Colors.black : NxColors.accent),
          ),
        ),
      ),
    );
  }
}

class ButtonsTest extends StatefulWidget {
  const ButtonsTest({super.key});

  @override
  State<ButtonsTest> createState() => _ButtonsTestState();
}

class _ButtonsTestState extends State<ButtonsTest> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  final _pressed = <String>{};
  final _down = <String>{};

  @override
  void initState() {
    super.initState();
    _sub = Native.keyStream().listen((e) {
      if (!mounted) return;
      final key = e['key'].toString();
      setState(() {
        if (e['down'] == true) {
          _down.add(key);
          _pressed.add(key);
        } else {
          _down.remove(key);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Widget _key(String id, String label, IconData icon) {
    final held = _down.contains(id);
    final tested = _pressed.contains(id);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: held ? NxColors.primary : (tested ? NxColors.ok.withValues(alpha: 0.2) : NxColors.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tested ? NxColors.ok : NxColors.muted.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 30, color: held ? Colors.white : (tested ? NxColors.ok : NxColors.muted)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: held ? Colors.white : null)),
        Text(tested ? 'OK' : 'non testé', style: TextStyle(fontSize: 10, color: tested ? NxColors.ok : NxColors.muted)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boutons physiques')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          NxCard(
            child: Text('Appuie sur chaque bouton. Il passe au vert une fois détecté. Pendant ce test, le volume ne change pas.',
                style: TextStyle(color: NxColors.muted, fontSize: 13)),
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: [
            _key('volume_up', 'Volume +', Icons.volume_up),
            _key('volume_down', 'Volume −', Icons.volume_down),
            _key('camera', 'Caméra', Icons.camera_alt),
          ]),
          const Spacer(),
          Text('Le bouton marche/arrêt et les boutons d’assistant ne sont pas transmis aux applications par Android.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: NxColors.muted)),
        ]),
      ),
    );
  }
}

class ProximityLightTest extends StatefulWidget {
  const ProximityLightTest({super.key});

  @override
  State<ProximityLightTest> createState() => _ProximityLightTestState();
}

class _ProximityLightTestState extends State<ProximityLightTest> {
  StreamSubscription<List<double>>? _prox;
  StreamSubscription<List<double>>? _light;
  double? _proxValue;
  double? _lightValue;

  @override
  void initState() {
    super.initState();
    _prox = Native.sensorStream(8).listen((v) {
      if (mounted && v.isNotEmpty) setState(() => _proxValue = v.first);
    }, onError: (_) {});
    _light = Native.sensorStream(5).listen((v) {
      if (mounted && v.isNotEmpty) setState(() => _lightValue = v.first);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _prox?.cancel();
    _light?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final near = _proxValue != null && _proxValue! < 5;
    return Scaffold(
      appBar: AppBar(title: const Text('Proximité & lumière')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NxCard(
            child: Column(children: [
              Icon(near ? Icons.pan_tool : Icons.waving_hand, size: 48, color: near ? NxColors.bad : NxColors.ok),
              const SizedBox(height: 8),
              Text(_proxValue == null ? 'Capteur de proximité absent' : (near ? 'OBJET DÉTECTÉ (proche)' : 'Rien devant (loin)'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (_proxValue != null) Text('${_proxValue!.toStringAsFixed(1)} cm', style: TextStyle(color: NxColors.muted, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Passe la main au-dessus du haut de l’écran.', style: TextStyle(fontSize: 12, color: NxColors.muted)),
            ]),
          ),
          const SizedBox(height: 12),
          NxCard(
            child: Column(children: [
              Icon(Icons.light_mode, size: 48, color: NxColors.accent),
              const SizedBox(height: 8),
              Text(_lightValue == null ? 'Capteur de luminosité absent' : '${_lightValue!.toStringAsFixed(0)} lux',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 4),
              Text('Couvre le capteur puis éclaire-le : la valeur doit changer.', style: TextStyle(fontSize: 12, color: NxColors.muted)),
            ]),
          ),
        ],
      ),
    );
  }
}

class CameraTest extends StatefulWidget {
  const CameraTest({super.key});

  @override
  State<CameraTest> createState() => _CameraTestState();
}

class _CameraTestState extends State<CameraTest> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _index = 0;
  String? _error;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Native.requestPermission('camera');
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'Aucune caméra détectée.');
        return;
      }
      await _open(0);
    } catch (e) {
      if (mounted) setState(() => _error = 'Caméra indisponible : $e');
    }
  }

  Future<void> _open(int index) async {
    await _controller?.dispose();
    final c = CameraController(_cameras[index], ResolutionPreset.high, enableAudio: false);
    _controller = c;
    try {
      await c.initialize();
      if (mounted) {
        setState(() {
          _index = index;
          _flash = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible d’ouvrir cette caméra : $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _label(CameraDescription d) {
    switch (d.lensDirection) {
      case CameraLensDirection.front:
        return 'Avant';
      case CameraLensDirection.back:
        return 'Arrière';
      default:
        return 'Externe';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caméras'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              tooltip: 'Changer de caméra',
              onPressed: () => _open((_index + 1) % _cameras.length),
            ),
        ],
      ),
      body: _error != null
          ? EmptyState(icon: Icons.videocam_off, text: _error!)
          : c == null || !c.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Expanded(child: Center(child: CameraPreview(c))),
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: NxColors.surface,
                    child: Column(children: [
                      Text('${_label(_cameras[_index])} · ${c.value.previewSize?.height.toInt() ?? '?'}×${c.value.previewSize?.width.toInt() ?? '?'}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, children: [
                        if (_cameras[_index].lensDirection == CameraLensDirection.back)
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              try {
                                await c.setFlashMode(_flash ? FlashMode.off : FlashMode.torch);
                                setState(() => _flash = !_flash);
                              } catch (_) {}
                            },
                            icon: Icon(_flash ? Icons.flash_on : Icons.flash_off),
                            label: const Text('Flash'),
                          ),
                        if (_cameras.length > 1)
                          FilledButton.tonalIcon(
                            onPressed: () => _open((_index + 1) % _cameras.length),
                            icon: const Icon(Icons.cameraswitch),
                            label: const Text('Avant / arrière'),
                          ),
                      ]),
                    ]),
                  ),
                ]),
    );
  }
}
