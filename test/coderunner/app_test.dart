import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/coderunner/api/deploy_files_client.dart';
import 'package:pathplanner/coderunner/app.dart';
import 'package:pathplanner/coderunner/config.dart';
import 'package:pathplanner/coderunner/web_mode.dart';
import 'package:pathplanner/pages/nav_grid_page.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeClient extends DeployFilesClient {
  final List<SnapshotFile> snapshot;
  final bool failSnapshot;

  FakeClient({this.snapshot = const [], this.failSnapshot = false})
      : super(baseUrl: '/unused');

  @override
  Future<List<SnapshotFile>> fetchSnapshot() async {
    if (failSnapshot) {
      throw const DeployFilesException(statusCode: 503, message: 'down');
    }
    return snapshot;
  }

  final List<String> puts = [];

  @override
  Future<void> putFile(String path, String content) async {
    puts.add(path);
  }

  @override
  Future<void> deleteFile(String path) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      // Suppress the one-time field-reset popup so the test sees the
      // project page directly.
      PrefsKeys.seen2026ResetPopup: true,
    });
  });

  tearDown(() {
    CodeRunnerWebMode.enabled = false;
  });

  testWidgets('boots into the project page from an empty snapshot',
      (tester) async {
    await tester.pumpWidget(CodeRunnerApp(
      config: const CodeRunnerConfig(workspaceSlug: 'tester'),
      appVersion: '0.0.0',
      client: FakeClient(),
    ));

    // Hydration future + HomePage init animations.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(CodeRunnerWebMode.enabled, true);
    expect(find.byType(ProjectPage), findsOneWidget);
  });

  testWidgets('replaces the app bar with a drawer button', (tester) async {
    await tester.pumpWidget(CodeRunnerApp(
      config: const CodeRunnerConfig(workspaceSlug: 'tester'),
      appVersion: '0.0.0',
      client: FakeClient(),
    ));

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.byType(CustomAppBar), findsNothing);

    final fab = find.widgetWithIcon(FloatingActionButton, Icons.menu);
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.text('Navigation Grid'), findsOneWidget);
    expect(find.text('Telemetry'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('opens the navgrid editor from the drawer', (tester) async {
    final client = FakeClient(snapshot: [
      SnapshotFile(
        path: 'src/main/deploy/pathplanner/navgrid.json',
        content: jsonEncode({
          'field_size': {'x': 17.55, 'y': 8.05},
          'nodeSizeMeters': 0.5,
          'grid': List.generate(17, (_) => List.filled(36, false)),
        }),
      ),
    ]);

    await tester.pumpWidget(CodeRunnerApp(
      config: const CodeRunnerConfig(workspaceSlug: 'tester'),
      appVersion: '0.0.0',
      client: client,
    ));

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Navigation Grid'));
    await tester.pumpAndSettle();

    // The editor is past its loading spinner, so navgrid.json hydrated
    // through the CodeRunner file system.
    expect(find.byType(NavGridPage), findsOneWidget);
    expect(
        find.descendant(
          of: find.byType(NavGridPage),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing);

    // Toggling a node writes back through the sync queue.
    await tester.tap(find.byType(NavGridPage));
    await tester.pumpAndSettle();

    expect(client.puts, contains('src/main/deploy/pathplanner/navgrid.json'));
  });

  testWidgets('shows a retryable error when hydration fails', (tester) async {
    await tester.pumpWidget(CodeRunnerApp(
      config: const CodeRunnerConfig(workspaceSlug: 'tester'),
      appVersion: '0.0.0',
      client: FakeClient(failSnapshot: true),
    ));

    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.textContaining('Failed to load'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  });
}
