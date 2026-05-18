// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:bugsnag_flutter/bugsnag_flutter.dart' as bs;
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_bugsnag/otel_bugsnag.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal `BugsnagClient` stub — only `addOnError` is exercised by
/// the bridge. Every other method is no-op via `noSuchMethod`.
class _FakeBugsnagClient implements bs.BugsnagClient {
  bs.BugsnagOnErrorCallback? captured;

  @override
  void addOnError(bs.BugsnagOnErrorCallback onError) {
    captured = onError;
  }

  @override
  void removeOnError(bs.BugsnagOnErrorCallback onError) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Construct a `BugsnagEvent` via its public `fromJson` constructor —
/// the only documented way to build one outside the platform
/// integration.
bs.BugsnagEvent _event({
  required String severity,
  required List<Map<String, Object?>> errors,
  List<Map<String, Object?>> breadcrumbs = const [],
  Map<String, Object?> user = const {},
  String? context,
  bool unhandled = false,
}) {
  return bs.BugsnagEvent.fromJson(<String, dynamic>{
    'exceptions': errors,
    'threads': <Map<String, Object?>>[],
    'breadcrumbs': breadcrumbs,
    'context': context,
    'unhandled': unhandled,
    'severity': severity,
    'severityReason': <String, Object?>{'type': 'handledException'},
    'user': user,
    'device': <String, Object?>{},
    'app': <String, Object?>{},
    'featureFlags': <Map<String, Object?>>[],
  });
}

Map<String, Object?> _error({
  required String errorClass,
  String? message,
  String type = 'dart',
}) {
  return <String, Object?>{
    'errorClass': errorClass,
    if (message != null) 'message': message,
    'type': type,
    'stacktrace': <Map<String, Object?>>[],
  };
}

Map<String, Object?> _breadcrumb({
  required String name,
  required String type,
  String? timestamp,
}) {
  return <String, Object?>{
    'name': name,
    'type': type,
    'timestamp': timestamp ?? '2026-05-13T22:00:00.000Z',
  };
}

void main() {
  late TestHarness harness;
  late InMemoryLogExporter logs;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_bugsnag-test',
    );
    logs = harness.logs;
  });

  setUp(() async {
    await harness.flushLogs();
    harness.clear();
  });

  Map<String, Object> attrsOf(LogRecord r) {
    final out = <String, Object>{};
    final list = r.attributes?.toList() ?? const <Attribute<Object>>[];
    for (final a in list) {
      out[a.key] = a.value;
    }
    return out;
  }

  group('installOTelBugsnagBridge — events', () {
    test('emits one ERROR log per BugsnagError with exception.* attrs',
        () async {
      final client = _FakeBugsnagClient();
      installOTelBugsnagBridge(client);
      expect(client.captured, isNotNull);

      final event = _event(
        severity: 'error',
        errors: [
          _error(errorClass: 'StateError', message: 'inventory out of stock'),
        ],
        user: const {'id': 'user-42', 'email': 'ada@example.com'},
        context: 'checkout-page',
        unhandled: false,
      );
      final pass = await client.captured!(event);
      expect(pass, isTrue, reason: 'bridge must let Bugsnag deliver upstream');
      await harness.flushLogs();

      expect(logs.records, hasLength(1));
      final rec = logs.records.single;
      expect(rec.severityNumber, Severity.ERROR);
      expect(rec.body, 'inventory out of stock');
      final a = attrsOf(rec);
      expect(a['exception.type'], 'StateError');
      expect(a['exception.message'], 'inventory out of stock');
      expect(a['bugsnag.error.class'], 'StateError');
      expect(a['bugsnag.error.type'], 'dart');
      expect(a['bugsnag.severity'], 'error');
      expect(a['bugsnag.unhandled'], false);
      expect(a['bugsnag.context'], 'checkout-page');
      expect(a['user.id'], 'user-42');
      expect(a['user.email'], 'ada@example.com');
    });

    test('maps BugsnagSeverity → OTel Severity', () async {
      final client = _FakeBugsnagClient();
      installOTelBugsnagBridge(client);

      for (final s in const ['error', 'warning', 'info']) {
        await client.captured!(_event(
          severity: s,
          errors: [_error(errorClass: 'X', message: s)],
        ));
      }
      await harness.flushLogs();
      expect(
        logs.records.map((r) => r.severityNumber).toList(),
        [Severity.ERROR, Severity.WARN, Severity.INFO],
      );
    });

    test('emits one INFO log per breadcrumb in event.breadcrumbs', () async {
      final client = _FakeBugsnagClient();
      installOTelBugsnagBridge(client);
      await client.captured!(_event(
        severity: 'error',
        errors: [_error(errorClass: 'X')],
        breadcrumbs: [
          _breadcrumb(name: 'tapped checkout', type: 'user'),
          _breadcrumb(name: 'GET /cart', type: 'request'),
        ],
      ));
      await harness.flushLogs();

      // 1 error log + 2 breadcrumb logs.
      expect(logs.records, hasLength(3));
      final crumbs =
          logs.records.where((r) => r.severityNumber == Severity.INFO).toList();
      expect(crumbs, hasLength(2));
      final messages = crumbs.map((r) => r.body).toList();
      expect(messages, containsAll(['tapped checkout', 'GET /cart']));
      final byMessage = {for (final r in crumbs) r.body: attrsOf(r)};
      expect(byMessage['tapped checkout']!['bugsnag.breadcrumb.type'], 'user');
      expect(byMessage['GET /cart']!['bugsnag.breadcrumb.type'], 'request');
    });

    test('bridgeBreadcrumbs:false skips breadcrumb emit', () async {
      final client = _FakeBugsnagClient();
      installOTelBugsnagBridge(client, bridgeBreadcrumbs: false);
      await client.captured!(_event(
        severity: 'error',
        errors: [_error(errorClass: 'X')],
        breadcrumbs: [_breadcrumb(name: 'crumb', type: 'manual')],
      ));
      await harness.flushLogs();
      // Only the error log.
      expect(logs.records, hasLength(1));
      expect(logs.records.single.severityNumber, Severity.ERROR);
    });

    test('multiple errors in one event → one log each', () async {
      final client = _FakeBugsnagClient();
      installOTelBugsnagBridge(client);
      await client.captured!(_event(
        severity: 'warning',
        errors: [
          _error(errorClass: 'AError', message: 'a'),
          _error(errorClass: 'BError', message: 'b'),
        ],
      ));
      await harness.flushLogs();
      final errors =
          logs.records.where((r) => r.severityNumber == Severity.WARN).toList();
      expect(errors, hasLength(2));
      expect(
        errors.map((r) => attrsOf(r)['bugsnag.error.class']).toList(),
        containsAll(['AError', 'BError']),
      );
    });

    test('bridge breadcrumb-count attr matches event.breadcrumbs.length',
        () async {
      final client = _FakeBugsnagClient();
      installOTelBugsnagBridge(client);
      await client.captured!(_event(
        severity: 'error',
        errors: [_error(errorClass: 'X')],
        breadcrumbs: [
          _breadcrumb(name: 'a', type: 'manual'),
          _breadcrumb(name: 'b', type: 'manual'),
          _breadcrumb(name: 'c', type: 'manual'),
        ],
      ));
      await harness.flushLogs();
      final errLog =
          logs.records.firstWhere((r) => r.severityNumber == Severity.ERROR);
      expect(attrsOf(errLog)['bugsnag.breadcrumb.count'], 3);
    });
  });

  group('suppression', () {
    test('runWithoutBugsnagBridgeAsync skips emit but returns true', () async {
      final client = _FakeBugsnagClient();
      installOTelBugsnagBridge(client);
      bool? result;
      await runWithoutBugsnagBridgeAsync(() async {
        result = await client.captured!(_event(
          severity: 'error',
          errors: [_error(errorClass: 'X', message: 'm')],
        ));
      });
      await harness.flushLogs();
      expect(result, isTrue);
      expect(logs.records, isEmpty);
    });
  });
}
