import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseBootstrap.initializeIfConfigured();

  runApp(const PharmacyApp());
}
