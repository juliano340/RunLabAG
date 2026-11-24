import 'package:flutter/foundation.dart';
import '../data/read_model_cache.dart';

/// Sinal global de mudança dos dados persistidos.
///
/// Não armazena dados: apenas avisa as abas vivas e, no próximo passo, o
/// cache compartilhado de que alguma leitura precisa ser invalidada.
class RunsProvider extends ChangeNotifier {
  final ReadModelCache? _cache;

  RunsProvider({ReadModelCache? cache}) : _cache = cache;

  void notifyRunSaved() => notifyDataChanged();

  void notifyDataChanged() {
    _cache?.invalidate();
    notifyListeners();
  }
}
