import 'package:flutter/foundation.dart';

/// Sinal global para notificar quando um novo treino de corrida é salvo.
/// Não armazena dados — apenas dispara notifyListeners() para que
/// HistoryTab (e outras telas) saibam que precisam recarregar do banco.
class RunsProvider extends ChangeNotifier {
  void notifyRunSaved() => notifyListeners();
}
