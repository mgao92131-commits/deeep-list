import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/services/database_service.dart';
import 'src/repositories/node_repository.dart';
import 'src/screens/node_screen.dart';
import 'src/models/node_item.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbService = DatabaseService();
  await dbService.isar;

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: dbService),
        ProxyProvider<DatabaseService, NodeRepository>(
          update: (_, db, __) => NodeRepository(db),
        ),
      ],
      child: const DeepListApp(),
    ),
  );
}

class DeepListApp extends StatelessWidget {
  const DeepListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepList',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0061A4)),
      ),
      home: const NodeScreen(nodeId: kRootNodeId),
    );
  }
}
