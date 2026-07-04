import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmHelper {
  // Firestore task id se ek consistent int alarm-id banata hai,
  // taaki schedule / cancel hamesha same id par ho.
  static int idFromTaskId(String taskId) => taskId.hashCode & 0x7fffffff;

  static Future<void> requestPermissions() async {
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    await Permission.notification.request();
  }

  static Future<void> scheduleTaskAlarm({
    required String taskId,
    required String title,
    required DateTime dateTime,
  }) async {
    if (dateTime.isBefore(DateTime.now())) return; // purana time, skip karo

    final alarmSettings = AlarmSettings(
      id: idFromTaskId(taskId),
      dateTime: dateTime,
      assetAudioPath:
          'assets/alarm.mpeg', // agar asset nahi dala to ye line hata do
      loopAudio: true,
      vibrate: true,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        volume: 1.0,
        fadeDuration: const Duration(seconds: 3),
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: 'Reminder Rewan Tech',
        body: title,
        stopButton: 'Stop',
        icon: 'notification_icon',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
  }

  static Future<void> cancelTaskAlarm(String taskId) async {
    await Alarm.stop(idFromTaskId(taskId));
  }
}
