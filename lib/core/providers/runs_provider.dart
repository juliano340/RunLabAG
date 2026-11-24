import 'package:flutter/foundation.dart';

/// Sinal global de mudança dos dados persistidos.
///
/// Não armazena dados: apenas avisa as abas vivas e, no próximo passo, o
/// cache compartilhado de que alguma leitura precisa ser invalidada.
class RunsProvider extends ChangeNotifier {
  void notifyRunSaved() => notifyDataChanged();

  void notifyDataChanged() => notifyListeners();
}
