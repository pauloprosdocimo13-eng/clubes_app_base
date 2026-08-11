import 'app_bootstrap.dart';

void main() {
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'guemes');
  bootstrapApp(flavor);
}
