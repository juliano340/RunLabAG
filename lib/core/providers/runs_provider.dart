import 'package:flutter/foundation.dart';

import '../data/data_change_hub.dart';
import '../data/read_model_cache.dart';

/// Ponte de compatibilidade para publicar mudanças no hub.
///
/// As telas novas escutam escopos diretamente pelo [DataChangeHub].
class RunsProvider extends ChangeNotifier {
  final DataChangeHub? _hub;

  RunsProvider({DataChangeHub? changes, ReadModelCache? cache})
    : _hub = changes ?? cache?.changes;

  void notifyRunSaved({Set<DataScope> scopes = const {DataScope.runs}}) {
    notifyDataChanged(scopes: scopes);
  }

  void notifyDataChanged({Set<DataScope> scopes = const {DataScope.all}}) {
    _hub?.emit(scopes);
    notifyListeners();
  }
}
