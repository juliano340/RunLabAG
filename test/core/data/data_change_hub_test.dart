import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/data/data_change_hub.dart';

void main() {
  test('escopos têm revisões independentes', () {
    final hub = DataChangeHub();
    addTearDown(hub.dispose);

    hub.emit({DataScope.profile});

    expect(hub.revision(DataScope.profile), 1);
    expect(hub.revision(DataScope.runs), 0);
    expect(hub.revision(DataScope.all), 0);
  });

  test('all invalida a assinatura de qualquer conjunto', () {
    final hub = DataChangeHub();
    addTearDown(hub.dispose);
    final runsBefore = hub.signature({DataScope.runs});
    final profileBefore = hub.signature({DataScope.profile});

    hub.emit({DataScope.all});

    expect(hub.signature({DataScope.runs}), isNot(runsBefore));
    expect(hub.signature({DataScope.profile}), isNot(profileBefore));
  });

  test('listener só reage ao próprio escopo ou a all', () {
    final hub = DataChangeHub();
    addTearDown(hub.dispose);
    var runChanges = 0;
    var profileChanges = 0;
    final runs = hub.listenableFor({DataScope.runs});
    final profile = hub.listenableFor({DataScope.profile});
    runs.addListener(() => runChanges++);
    profile.addListener(() => profileChanges++);

    hub.emit({DataScope.runs});
    expect(runChanges, 1);
    expect(profileChanges, 0);

    hub.emit({DataScope.all});
    expect(runChanges, 2);
    expect(profileChanges, 1);
  });
}
