import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart' as sf;
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:provider/provider.dart';

import '../controllers/app_ctrl.dart' show AppCtrl, AgentScreenState;
import '../controllers/tool_status_ctrl.dart';
import '../controllers/wake_word_state_ctrl.dart';
import '../ui/color_pallette.dart' show LKColorPaletteLight;
import 'floating_glass.dart';
import 'settings_modal.dart';

const _wakeWordBlue = Color(0xFF3B82F6);  // Sleeping - waiting for wake word
const _wakeWordGreen = Color(0xFF22C55E); // Listening - active conversation

class ControlBar extends StatelessWidget {
  const ControlBar({super.key});

  void _showToolDetails(BuildContext context, ToolStatus status) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ToolDetailsSheet(status: status),
    );
  }

  @override
  Widget build(BuildContext ctx) => FloatingGlassView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 10,
          ),
          child: Row(
            spacing: 5,
            children: [
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: components.MediaDeviceContextBuilder(
                  builder: (context, roomCtx, mediaDeviceCtx) => FloatingGlassButton(
                    sfIcon: mediaDeviceCtx.microphoneOpened
                        ? sf.SFIcons.sf_microphone_fill
                        : sf.SFIcons.sf_microphone_slash_fill,
                    subWidget: components.ParticipantSelector(
                      filter: (identifier) => identifier.isAudio && identifier.isLocal,
                      builder: (context, identifier) => const SizedBox(
                        width: 15,
                        height: 15,
                        child: components.AudioVisualizerWidget(
                          options: components.AudioVisualizerWidgetOptions(
                            barCount: 5,
                            spacing: 1,
                            // color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    onTap: () {
                      mediaDeviceCtx.microphoneOpened
                          ? mediaDeviceCtx.disableMicrophone()
                          : mediaDeviceCtx.enableMicrophone();
                    },
                  ),
                ),
              ),
              Selector<AppCtrl, AgentScreenState>(
                selector: (ctx, appCtx) => appCtx.agentScreenState,
                builder: (context, agentScreenState, child) => Flexible(
                  flex: 1,
                  fit: FlexFit.tight,
                  child: FloatingGlassButton(
                    isActive: agentScreenState == AgentScreenState.transcription,
                    sfIcon: sf.SFIcons.sf_ellipsis_message_fill,
                    onTap: () => ctx.read<AppCtrl>().toggleAgentScreenMode(),
                  ),
                ),
              ),
              // Tool indicator button
              Consumer<ToolStatusCtrl>(
                builder: (context, toolCtrl, _) {
                  final status = toolCtrl.status;
                  final isActive = status.toolUsed;
                  return Flexible(
                    flex: 1,
                    fit: FlexFit.tight,
                    child: FloatingGlassButton(
                      isActive: isActive,
                      iconColor: isActive ? const Color(0xFF45997C) : null,
                      sfIcon: sf.SFIcons.sf_wrench_and_screwdriver_fill,
                      onTap: isActive ? () => _showToolDetails(context, status) : null,
                    ),
                  );
                },
              ),
              // Wake word toggle button with auto-mute logic
              const _WakeWordButton(),
              // Settings button
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: FloatingGlassButton(
                  sfIcon: sf.SFIcons.sf_gearshape_fill,
                  onTap: () => SettingsModal.show(ctx),
                ),
              ),
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: FloatingGlassButton(
                  iconColor: LKColorPaletteLight().fgModerate,
                  sfIcon: sf.SFIcons.sf_phone_down_fill,
                  onTap: () => ctx.read<AppCtrl>().disconnect(),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ToolDetailsSheet extends StatelessWidget {
  final ToolStatus status;

  const _ToolDetailsSheet({required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.build,
                color: Color(0xFF45997C),
                size: 20,
              ),
              SizedBox(width: 10),
              Text(
                'Tool Parameters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < status.toolNames.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _ToolEntry(
              name: status.toolNames[i],
              params: i < status.toolParams.length ? status.toolParams[i] : {},
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ToolEntry extends StatelessWidget {
  final String name;
  final Map<String, dynamic> params;

  const _ToolEntry({
    required this.name,
    required this.params,
  });

  @override
  Widget build(BuildContext context) {
    final encoder = const JsonEncoder.withIndent('  ');
    final paramsJson = encoder.convert(params);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Color(0xFF45997C),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            paramsJson,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

/// Wake word indicator showing server-side wake word state.
/// Blue = sleeping (waiting for wake word), Green = active (processing conversation).
class _WakeWordButton extends StatelessWidget {
  const _WakeWordButton();

  @override
  Widget build(BuildContext context) {
    return Consumer<WakeWordStateCtrl>(
      builder: (context, wakeWordStateCtrl, _) {
        final serverState = wakeWordStateCtrl.state;
        final isEnabled = wakeWordStateCtrl.isEnabled;

        // Determine icon color based on state
        // Grey if disabled, blue if sleeping, green if active
        final Color iconColor;
        if (!isEnabled) {
          iconColor = Colors.grey;
        } else if (serverState == WakeWordState.active) {
          iconColor = _wakeWordGreen;
        } else {
          iconColor = _wakeWordBlue;
        }

        return Flexible(
          flex: 1,
          fit: FlexFit.tight,
          child: FloatingGlassButton(
            isActive: false,
            iconColor: iconColor,
            sfIcon: sf.SFIcons.sf_ear_fill,
            onTap: () {}, // Empty callback to avoid opacity fade
          ),
        );
      },
    );
  }
}
