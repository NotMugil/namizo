import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/models/update_info.dart';
import 'package:namizo/services/update.dart';

final updateCheckRefreshProvider = StateProvider<int>((ref) => 0);

final updateDownloadProgressProvider = StateProvider<double?>((ref) => null);

final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  ref.watch(updateCheckRefreshProvider);
  return UpdateService.checkForUpdate();
});
