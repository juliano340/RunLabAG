import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/data/data_change_hub.dart';
import 'package:runlabag/core/providers/runs_provider.dart';

void main() {
  test('RunsProvider publica escopos no hub', () async {
    final hub = DataChangeHub();
    addTearDown(hub.dispose);
    final provider = RunsProvider(changes: hub);
    addTearDown(provider.dispose);
    final events = <Set<DataScope>>[];
    final subscription = hub.changes.listen(events.add);
    addTearDown(subscription.cancel);

    provider.notifyRunSaved();
    provider.notifyDataChanged(scopes: {DataScope.profile});
    await Future<void>.delayed(Duration.zero);

    expect(events, [
      {DataScope.runs},
      {DataScope.profile},
    ]);
  });
}
