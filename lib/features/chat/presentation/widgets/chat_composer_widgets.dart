import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import 'chat_media_widgets.dart';
import 'voice_recorder.dart';

enum AttachmentChoice { photoCamera, photoGallery, videoCamera, videoGallery }

/// The "attach" menu: camera / gallery, photo / video.
Future<AttachmentChoice?> showAttachmentSheet(BuildContext context) {
  Widget tile(
    BuildContext sheetContext,
    IconData icon,
    Color color,
    String label,
    AttachmentChoice choice,
  ) => ListTile(
    leading: CircleAvatar(
      backgroundColor: color,
      child: Icon(icon, color: Colors.white),
    ),
    title: Text(label),
    onTap: () => Navigator.pop(sheetContext, choice),
  );

  return showModalBottomSheet<AttachmentChoice>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          tile(
            sheetContext,
            Icons.photo_camera_rounded,
            const Color(0xFFE91E63),
            sheetContext.l10n.takePhoto,
            AttachmentChoice.photoCamera,
          ),
          tile(
            sheetContext,
            Icons.photo_library_rounded,
            const Color(0xFF7E57C2),
            sheetContext.l10n.photosFromGallery,
            AttachmentChoice.photoGallery,
          ),
          tile(
            sheetContext,
            Icons.videocam_rounded,
            const Color(0xFFEF6C00),
            sheetContext.l10n.recordVideo,
            AttachmentChoice.videoCamera,
          ),
          tile(
            sheetContext,
            Icons.video_library_rounded,
            const Color(0xFF1E88E5),
            sheetContext.l10n.videoFromGallery,
            AttachmentChoice.videoGallery,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Shown in place of the text field while a voice message is recording.
/// The bin button on the left discards the recording.
class RecordingBar extends StatelessWidget {
  const RecordingBar({
    super.key,
    required this.controller,
    required this.background,
    required this.textColor,
    required this.hintColor,
  });

  final VoiceRecorderController controller;
  final Color background;
  final Color textColor;
  final Color hintColor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          height: 48,
          padding: const EdgeInsetsDirectional.only(start: 4, end: 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: context.l10n.cancel,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: controller.cancel,
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.fiber_manual_record,
                color: AppColors.error,
                size: 12,
              ),
              const SizedBox(width: 8),
              Text(
                formatMediaDuration(controller.elapsed),
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.slideToCancel,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: hintColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The mic button: tap to start recording; while recording it turns into a
/// send button (tap to stop and send). Cancel with the bin in [RecordingBar].
class VoiceMicButton extends StatelessWidget {
  const VoiceMicButton({
    super.key,
    required this.controller,
    required this.onRecorded,
    required this.onPermissionDenied,
    required this.onTooShort,
  });

  final VoiceRecorderController controller;
  final void Function(VoiceRecording recording) onRecorded;
  final VoidCallback onPermissionDenied;
  final VoidCallback onTooShort;

  static const _minDuration = Duration(seconds: 1);

  Future<void> _send() async {
    final recording = await controller.finish();
    if (recording == null) return;
    if (recording.duration < _minDuration) {
      try {
        await recording.file.delete();
      } catch (_) {}
      onTooShort();
      return;
    }
    onRecorded(recording);
  }

  Future<void> _start() async {
    final started = await controller.start();
    if (!started) onPermissionDenied();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final recording = controller.isRecording;
        return Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: recording ? _send : _start,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                recording ? Icons.send_rounded : Icons.mic,
                size: 24,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}
