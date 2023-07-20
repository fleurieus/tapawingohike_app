import 'package:cron/cron.dart';

Cron _cron = Cron();

void startCronjob(func, int duration) {
  _cron = Cron();
  _cron.schedule(Schedule.parse('*/${duration.toString()} * * * *'), () {
    func();
  });
}

void stopCronjob() {
  _cron.close();
}
