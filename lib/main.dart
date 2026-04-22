import 'package:debt_free_app/app/app.dart';
import 'package:debt_free_app/core/data/session_financial_repository.dart';
import 'package:debt_free_app/core/services/subscription_service.dart';
import 'package:debt_free_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final repo = SessionFinancialRepository.instance;
  await repo.hydrate();
  await SubscriptionService.instance.initialize(repo.database);
  runApp(const DebtFreeApp());
}
