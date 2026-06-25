import 'package:cloak_core/cloak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_dao.dart';
import 'providers.dart';

class ProfileListController extends AsyncNotifier<List<Profile>> {
  @override
  Future<List<Profile>> build() => ref.watch(profileDaoProvider).all();

  ProfileDao get _dao => ref.read(profileDaoProvider);

  Future<Profile> create(String name) async {
    final now = DateTime.now().toUtc();
    final profile = Profile(
      id: _newId(now),
      name: name,
      colorHex: '#5E81F4',
      iconName: 'person',
      createdAt: now,
      updatedAt: now,
      stealth: StealthConfig(proxy: ProxyConfig.disabled()),
    );
    await _dao.upsert(profile);
    await _reload();
    return profile;
  }

  Future<void> save(Profile profile) async {
    await _dao.upsert(profile);
    await _reload();
  }

  Future<void> remove(String id) async {
    await _dao.delete(id);
    await _reload();
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(() => _dao.all());
  }

  static String _newId(DateTime now) =>
      '${now.microsecondsSinceEpoch.toRadixString(36)}'
      '-${now.hashCode.toRadixString(36)}';
}

final profileListProvider =
    AsyncNotifierProvider<ProfileListController, List<Profile>>(
        ProfileListController.new);
