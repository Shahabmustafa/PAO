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
        final cancelling = controller.willCancel;
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                cancelling ? Icons.delete_outline : Icons.mic,
                color: AppColors.error,
                size: 22,
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
              const Spacer(),
              Text(
                cancelling
                    ? context.l10n.releaseToCancel
                    : '‹  ${context.l10n.slideToCancel}',
                style: TextStyle(
                  fontSize: 14,
                  color: cancelling ? AppColors.error : hintColor,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }
}

/// The mic button: hold to record, release to send, slide towards the
/// start edge to cancel.
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

  static const _cancelDistance = 90.0;
  static const _minDuration = Duration(seconds: 1);

  Future<void> _end({required bool cancel}) async {
    if (cancel) {
      await controller.cancel();
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final recording = controller.isRecording;
        return GestureDetector(
          onTap: onTooShort,
          onLongPressStart: (_) async {
            final started = await controller.start();
            if (!started) onPermissionDenied();
          },
          onLongPressMoveUpdate: (details) {
            final towardsStart = details.offsetFromOrigin.dx * (isRtl ? -1 : 1);
            controller.setWillCancel(towardsStart < -_cancelDistance);
          },
          onLongPressEnd: (_) => _end(cancel: controller.willCancel),
          onLongPressCancel: () => _end(cancel: true),
          child: AnimatedScale(
            scale: recording ? 1.35 : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: controller.willCancel
                    ? AppColors.error
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mic, size: 24, color: AppColors.onPrimary),
            ),
          ),
        );
      },
    );
  }
}
