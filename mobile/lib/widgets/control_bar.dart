import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart' as sf;
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:provider/provider.dart';

import '../controllers/app_ctrl.dart' show AppCtrl, AgentScreenState;
import '../controllers/tool_status_ctrl.dart';
import '../exts.dart';
import '../ui/color_pallette.dart' show LKColorPaletteLight;
import 'floating_glass.dart';

const _wakeWordBlue = Color(0xFF3B82F6);
const _autoMuteDelay = Duration(seconds: 4);

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

/// Wake word button with auto-mute logic.
/// Tracks agent state and auto-mutes mic after agent finishes speaking.
class _WakeWordButton extends StatefulWidget {
  const _WakeWordButton();

  @override
  State<_WakeWordButton> createState() => _WakeWordButtonState();
}

class _WakeWordButtonState extends State<_WakeWordButton> {
  Timer? _autoMuteTimer;
  sdk.AgentState? _lastAgentState;
  bool _wasAgentActive = false;
  bool _hasUserSpoken = false;

  @override
  void dispose() {
    _autoMuteTimer?.cancel();
    super.dispose();
  }

  void _onAgentStateChanged(sdk.AgentState? newState, components.MediaDeviceContext mediaDeviceCtx) {
    final wakeWord = context.read<AppCtrl>().wakeWordService;
    if (!wakeWord.isEnabled) {
      _wasAgentActive = false;
      _hasUserSpoken = false;
      _autoMuteTimer?.cancel();
      return;
    }

    // Track when agent becomes active (speaking or thinking)
    if (newState == sdk.AgentState.speaking || newState == sdk.AgentState.thinking) {
      _wasAgentActive = true;
      // If agent is thinking and mic is on, user has spoken
      if (newState == sdk.AgentState.thinking && mediaDeviceCtx.microphoneOpened) {
        _hasUserSpoken = true;
        // Cancel pending auto-mute if user spoke during delay
        _autoMuteTimer?.cancel();
        debugPrint('[WakeWordButton] User spoke, canceling auto-mute');
      }
    }

    // When agent returns to listening after being active, schedule auto-mute
    if (newState == sdk.AgentState.listening && _wasAgentActive && mediaDeviceCtx.microphoneOpened && _hasUserSpoken) {
      _wasAgentActive = false;
      _autoMuteTimer?.cancel();

      debugPrint('[WakeWordButton] Agent finished, will mute in ${_autoMuteDelay.inSeconds}s');
      _autoMuteTimer = Timer(_autoMuteDelay, () {
        if (wakeWord.isEnabled && mediaDeviceCtx.microphoneOpened) {
          debugPrint('[WakeWordButton] Auto-muting mic');
          mediaDeviceCtx.disableMicrophone();
          _hasUserSpoken = false;
        }
      });
    }

    _lastAgentState = newState;
  }

  @override
  Widget build(BuildContext context) {
    return components.MediaDeviceContextBuilder(
      builder: (context, roomCtx, mediaDeviceCtx) {
        final wakeWord = context.read<AppCtrl>().wakeWordService;

        // Set the unmute callback so wake word detection can enable mic
        wakeWord.onUnmuteMic = () => mediaDeviceCtx.enableMicrophone();

        // Listen to agent state changes for auto-mute
        final agentParticipant = roomCtx.agentParticipant;
        final agentState = agentParticipant?.agentState;

        // Check for state change
        if (agentState != _lastAgentState) {
          // Use post-frame callback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onAgentStateChanged(agentState, mediaDeviceCtx);
          });
        }

        // Check if wake word is configured (has access key)
        final appCtrl = context.read<AppCtrl>();
        final isConfigured = appCtrl.porcupineAccessKey.isNotEmpty;

        return ListenableBuilder(
          listenable: wakeWord,
          builder: (context, _) {
            final isEnabled = wakeWord.isEnabled;
            return Flexible(
              flex: 1,
              fit: FlexFit.tight,
              child: FloatingGlassButton(
                isActive: isEnabled,
                iconColor: isEnabled ? _wakeWordBlue : (isConfigured ? null : Colors.grey),
                sfIcon: sf.SFIcons.sf_ear_fill,
                onTap: isConfigured
                    ? () async {
                        final enabled = await wakeWord.toggle();
                        if (enabled) {
                          // When wake word enabled, mute mic
                          mediaDeviceCtx.disableMicrophone();
                        } else {
                          // When disabled, cancel any pending auto-mute
                          _autoMuteTimer?.cancel();
                          _hasUserSpoken = false;
                          _wasAgentActive = false;
                        }
                      }
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
