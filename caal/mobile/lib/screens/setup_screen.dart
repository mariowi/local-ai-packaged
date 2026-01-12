import 'package:flutter/material.dart';

import '../services/config_service.dart';

/// Setup screen for initial server URL configuration.
/// Full agent settings are available via the gear icon in the control bar
/// during an active session.
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = widget.configService.serverUrl;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await widget.configService.setServerUrl(_serverUrlController.text.trim());
      widget.onConfigured();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirstSetup = !widget.configService.isConfigured;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: isFirstSetup
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF1A1A1A),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('Connection', style: TextStyle(color: Colors.white)),
            ),
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
                  if (isFirstSetup) ...[
                    const Icon(Icons.graphic_eq, size: 80, color: Colors.white),
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
                      'Enter your server address to get started',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                  ],

                  // Server URL field
                  const Text(
                    'Server URL',
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
                      hintStyle: const TextStyle(color: Colors.white38),
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
                    style: TextStyle(fontSize: 12, color: Colors.white54),
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
                          : Text(
                              isFirstSetup ? 'CONNECT' : 'SAVE',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  if (isFirstSetup) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Full agent settings are available during an active session via the gear icon.',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
