# RunLab — regras do R8
# Plugins (Flutter, Firebase, AdMob, Geolocator) já trazem as suas próprias
# consumer rules. Estas regras cobrem apenas o que o app carrega por reflexão.

-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Modelos serializados via jsonEncode/jsonDecode não usam reflexão, mas o
# Crashlytics e o AdMob dependem dos nomes das classes para relatórios.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

-dontwarn io.flutter.embedding.**
