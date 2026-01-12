import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../controllers/app_ctrl.dart';

/// Settings modal that fetches and saves settings from the server API.
/// Only available during an active session (webhook server must be running).
class SettingsModal extends StatefulWidget {
  final ScrollController? scrollController;

  const SettingsModal({super.key, this.scrollController});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SettingsModal(
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Settings fields
  String _agentName = 'Cal';
  String _ttsVoice = 'am_puck';
  String _model = 'ministral-3:8b';
  List<String> _wakeGreetings = ["Hey, what's up?", "What's up?", 'How can I help?'];
  double _temperature = 0.7;
  int _numCtx = 8192;
  int _maxTurns = 20;
  int _toolCacheSize = 3;
  bool _wakeWordEnabled = false;
  String _wakeWordModel = 'models/hey_cal.onnx';
  double _wakeWordThreshold = 0.5;
  double _wakeWordTimeout = 3.0;
  // Turn detection (advanced)
  bool _allowInterruptions = true;
  double _minEndpointingDelay = 0.5;

  // Available options
  List<String> _voices = [];
  List<String> _models = [];
  List<String> _wakeWordModels = [];

  // Text controllers
  final _wakeGreetingsController = TextEditingController();

  String get _webhookUrl {
    final serverUrl = context.read<AppCtrl>().serverUrl;
    final uri = Uri.parse(serverUrl);
    return 'http://${uri.host}:8889';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _wakeGreetingsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_webhookUrl/settings')),
        http.get(Uri.parse('$_webhookUrl/voices')),
        http.get(Uri.parse('$_webhookUrl/models')),
        http.get(Uri.parse('$_webhookUrl/wake-word/models')),
      ]);

      final settingsRes = results[0];
      final voicesRes = results[1];
      final modelsRes = results[2];
      final wakeWordModelsRes = results[3];

      if (settingsRes.statusCode == 200) {
        final data = jsonDecode(settingsRes.body);
        final settings = data['settings'] ?? {};

        setState(() {
          _agentName = settings['agent_name'] ?? _agentName;
          _ttsVoice = settings['tts_voice'] ?? _ttsVoice;
          _model = settings['model'] ?? _model;
          _wakeGreetings = List<String>.from(settings['wake_greetings'] ?? _wakeGreetings);
          _temperature = (settings['temperature'] ?? _temperature).toDouble();
          _numCtx = settings['num_ctx'] ?? _numCtx;
          _maxTurns = settings['max_turns'] ?? _maxTurns;
          _toolCacheSize = settings['tool_cache_size'] ?? _toolCacheSize;
          _wakeWordEnabled = settings['wake_word_enabled'] ?? _wakeWordEnabled;
          _wakeWordModel = settings['wake_word_model'] ?? _wakeWordModel;
          _wakeWordThreshold = (settings['wake_word_threshold'] ?? _wakeWordThreshold).toDouble();
          _wakeWordTimeout = (settings['wake_word_timeout'] ?? _wakeWordTimeout).toDouble();
          _allowInterruptions = settings['allow_interruptions'] ?? _allowInterruptions;
          _minEndpointingDelay = (settings['min_endpointing_delay'] ?? _minEndpointingDelay).toDouble();
          _wakeGreetingsController.text = _wakeGreetings.join('\n');
        });
      }

      if (voicesRes.statusCode == 200) {
        final data = jsonDecode(voicesRes.body);
        setState(() {
          _voices = List<String>.from(data['voices'] ?? []);
        });
      }

      if (modelsRes.statusCode == 200) {
        final data = jsonDecode(modelsRes.body);
        setState(() {
          _models = List<String>.from(data['models'] ?? []);
        });
      }

      if (wakeWordModelsRes.statusCode == 200) {
        final data = jsonDecode(wakeWordModelsRes.body);
        setState(() {
          _wakeWordModels = List<String>.from(data['models'] ?? []);
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load settings: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Parse wake greetings from text
      final greetings =
          _wakeGreetingsController.text.split('\n').where((g) => g.trim().isNotEmpty).toList();

      final settings = {
        'agent_name': _agentName,
        'tts_voice': _ttsVoice,
        'model': _model,
        'wake_greetings': greetings,
        'temperature': _temperature,
        'num_ctx': _numCtx,
        'max_turns': _maxTurns,
        'tool_cache_size': _toolCacheSize,
        'wake_word_enabled': _wakeWordEnabled,
        'wake_word_model': _wakeWordModel,
        'wake_word_threshold': _wakeWordThreshold,
        'wake_word_timeout': _wakeWordTimeout,
        'allow_interruptions': _allowInterruptions,
        'min_endpointing_delay': _minEndpointingDelay,
      };

      final res = await http.post(
        Uri.parse('$_webhookUrl/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'settings': settings}),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _error = 'Failed to save settings: ${res.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save settings: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFF45997C), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF45997C),
                  ),
                )
              : ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Agent Name
                    _buildTextField(
                      label: 'Agent Name',
                      value: _agentName,
                      onChanged: (v) => setState(() => _agentName = v),
                    ),

                    // Voice
                    _buildDropdown(
                      label: 'Voice',
                      value: _ttsVoice,
                      options: _voices.isNotEmpty ? _voices : [_ttsVoice],
                      onChanged: (v) => setState(() => _ttsVoice = v ?? _ttsVoice),
                    ),

                    // Model
                    _buildDropdown(
                      label: 'Model',
                      value: _model,
                      options: _models.isNotEmpty ? _models : [_model],
                      onChanged: (v) => setState(() => _model = v ?? _model),
                    ),

                    // Numeric settings row 1
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberField(
                            label: 'Temperature',
                            value: _temperature,
                            min: 0.0,
                            max: 2.0,
                            decimals: 1,
                            onChanged: (v) => setState(() => _temperature = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildIntField(
                            label: 'Context Size',
                            value: _numCtx,
                            min: 1024,
                            max: 131072,
                            step: 1024,
                            onChanged: (v) => setState(() => _numCtx = v),
                          ),
                        ),
                      ],
                    ),

                    // Numeric settings row 2
                    Row(
                      children: [
                        Expanded(
                          child: _buildIntField(
                            label: 'Max Turns',
                            value: _maxTurns,
                            min: 1,
                            max: 100,
                            onChanged: (v) => setState(() => _maxTurns = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildIntField(
                            label: 'Tool Cache',
                            value: _toolCacheSize,
                            min: 0,
                            max: 10,
                            onChanged: (v) => setState(() => _toolCacheSize = v),
                          ),
                        ),
                      ],
                    ),

                    // Wake Word Section
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Server-Side Wake Word',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Activate with wake phrase',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _wakeWordEnabled,
                                onChanged: (v) => setState(() => _wakeWordEnabled = v),
                                activeTrackColor: const Color(0xFF45997C),
                              ),
                            ],
                          ),
                          if (_wakeWordEnabled) ...[
                            const SizedBox(height: 12),
                            // Wake Word Model Dropdown
                            _buildWakeWordModelDropdown(),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildNumberField(
                                    label: 'Threshold',
                                    value: _wakeWordThreshold,
                                    min: 0.1,
                                    max: 1.0,
                                    decimals: 1,
                                    onChanged: (v) => setState(() => _wakeWordThreshold = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildNumberField(
                                    label: 'Timeout (s)',
                                    value: _wakeWordTimeout,
                                    min: 1.0,
                                    max: 30.0,
                                    decimals: 1,
                                    onChanged: (v) => setState(() => _wakeWordTimeout = v),
                                  ),
                                ),
                              ],
                            ),
                            // Wake Greetings
                            const Text(
                              'Wake Greetings (one per line)',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _wakeGreetingsController,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Advanced: Turn Detection Section
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Advanced: Turn Detection',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Allow Interruptions Toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Allow Interruptions',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Interrupt agent while speaking',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _allowInterruptions,
                                onChanged: (v) => setState(() => _allowInterruptions = v),
                                activeTrackColor: const Color(0xFF45997C),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Endpointing Delay Slider
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Endpointing Delay (${_minEndpointingDelay.toStringAsFixed(1)}s)',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const Text(
                                'Wait time before turn complete',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF45997C),
                                  thumbColor: const Color(0xFF45997C),
                                  inactiveTrackColor: Colors.white24,
                                ),
                                child: Slider(
                                  value: _minEndpointingDelay,
                                  min: 0.1,
                                  max: 2.0,
                                  divisions: 19,
                                  onChanged: (v) => setState(() => _minEndpointingDelay = v),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text('Fast (0.1s)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                  Text('Slow (2.0s)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      'Note: Model, context size, and wake word changes take effect on next session.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _loading || _saving ? null : _saveSettings,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF45997C),
                  foregroundColor: const Color(0xFF171717),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Color(0xFF171717)),
                          ),
                        )
                      : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          initialValue: value,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    // Ensure value is in options
    final safeValue = options.contains(value) ? value : (options.isNotEmpty ? options.first : value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        DropdownButtonFormField<String>(
          initialValue: safeValue,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF2A2A2A),
          decoration: _inputDecoration(),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNumberField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int decimals,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          initialValue: value.toStringAsFixed(decimals),
          style: const TextStyle(color: Colors.white),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration(),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null && parsed >= min && parsed <= max) {
              onChanged(parsed);
            }
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildIntField({
    required String label,
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          initialValue: value.toString(),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: _inputDecoration(),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null && parsed >= min && parsed <= max) {
              onChanged(parsed);
            }
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Format model path for display: "models/hey_cal.onnx" -> "Hey Cal"
  String _formatModelName(String path) {
    return path
        .replaceAll('models/', '')
        .replaceAll('.onnx', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  Widget _buildWakeWordModelDropdown() {
    final options = _wakeWordModels.isNotEmpty ? _wakeWordModels : [_wakeWordModel];
    final safeValue = options.contains(_wakeWordModel) ? _wakeWordModel : options.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wake Word Model',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: safeValue,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF2A2A2A),
          decoration: _inputDecoration(),
          items: options
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(_formatModelName(m)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _wakeWordModel = v ?? _wakeWordModel),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
