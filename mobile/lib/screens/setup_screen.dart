import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../services/config_service.dart';

/// Setup screen for configuring the app on first launch.
/// Allows users to enter server URL and optional Porcupine access key.
class SetupScreen extends StatefulWidget {
  final ConfigService configService;
  final VoidCallback onConfigured;

  const SetupScreen({
    super.key,
    required this.configService,
    required this.onConfigured,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _porcupineKeyController = TextEditingController();
  bool _isSaving = false;
  String? _selectedFileName;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing values if editing
    _serverUrlController.text = widget.configService.serverUrl;
    _porcupineKeyController.text = widget.configService.porcupineAccessKey;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _porcupineKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await widget.configService.setServerUrl(_serverUrlController.text);
      await widget.configService.setPorcupineAccessKey(_porcupineKeyController.text);

      // Copy .ppn file to app storage if selected
      if (_selectedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final destPath = p.join(appDir.path, 'wakeword.ppn');
        await _selectedFile!.copy(destPath);
        await widget.configService.setWakeWordPath(destPath);
      }

      widget.onConfigured();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickWakeWordFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      // Validate .ppn extension
      if (!fileName.toLowerCase().endsWith('.ppn')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a .ppn file')),
          );
        }
        return;
      }

      setState(() {
        _selectedFile = file;
        _selectedFileName = fileName;
      });
    }
  }

  Future<void> _openPicovoiceConsole() async {
    final uri = Uri.parse('https://console.picovoice.ai/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Icon(
                    Icons.graphic_eq,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CAAL Setup',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure your connection settings',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Server URL field
                  const Text(
                    'Server URL *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _serverUrlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'http://192.168.1.100:3000',
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Server URL is required';
                      }
                      final uri = Uri.tryParse(value.trim());
                      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                        return 'Enter a valid URL (e.g., http://192.168.1.100:3000)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your CAAL server address',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Wake Word Configuration section header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF232323),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.hearing,
                              size: 20,
                              color: const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Wake Word (Optional)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enable hands-free activation with a custom wake word',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Porcupine Access Key field
                        const Text(
                          'Picovoice Access Key',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _porcupineKeyController,
                          autocorrect: false,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter your Picovoice access key',
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Wake Word File section
                        const Text(
                          'Wake Word File (.ppn)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _selectedFileName ??
                                      (widget.configService.wakeWordPath.isNotEmpty
                                          ? p.basename(widget.configService.wakeWordPath)
                                          : 'No file selected'),
                                  style: const TextStyle(color: Colors.white70),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: _pickWakeWordFile,
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Browse'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _openPicovoiceConsole,
                          child: const Text(
                            'Get a free key and train a wake word at console.picovoice.ai',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF3B82F6),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Save button
                  SizedBox(
                    height: 50,
                    child: TextButton(
                      onPressed: _isSaving ? null : _save,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF45997C),
                        foregroundColor: const Color(0xFF171717),
                        disabledForegroundColor: const Color(0xFF171717),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Color(0xFF171717)),
                              ),
                            )
                          : const Text(
                              'SAVE',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
