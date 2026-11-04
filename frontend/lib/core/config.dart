/// URL da API (equivalente ao VITE_API_URL do front React).
/// Defina na execução/build:
///   flutter run --dart-define=API_URL=http://localhost:3333
/// No emulador Android use http://10.0.2.2:3333 para acessar o localhost da máquina.
const String kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3333',
);
