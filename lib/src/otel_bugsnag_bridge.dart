// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:bugsnag_flutter/bugsnag_flutter.dart' as bs;
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'bugsnag_semantics.dart';
import 'otel_bugsnag_suppression.dart';

const _loggerName = 'package.bugsnag_flutter';

/// Installs the Bugsnag → OTel bridge on a [bs.BugsnagClient].
///
/// Call after `bugsnag.start(...)`:
///
/// ```dart
/// await bugsnag.start(apiKey: const String.fromEnvironment('BUGSNAG_KEY'));
/// installOTelBugsnagBridge(bugsnag);
/// ```
///
/// Every error Bugsnag captures (handled `bugsnag.notify(...)` calls
/// plus unhandled crashes routed through the platform integration)
/// also lands as an OpenTelemetry log record: one log per
/// `BugsnagError` in the event, with severity mapped from
/// `BugsnagSeverity` (error → ERROR, warning → WARN, info → INFO).
/// Breadcrumbs attached to the event each become a separate INFO log
/// so they're queryable individually in your OTel backend.
///
/// Records inherit `trace_id` / `span_id` from `Context.current`, so
/// errors captured inside a `tracer.withSpan` block appear on that
/// span — your trace view and your Bugsnag dashboard show the same
/// event, linked by ID.
///
/// The bridge is **additive**: returning `true` from the OnError
/// callback lets Bugsnag continue to deliver the event upstream.
/// Existing OnError callbacks the app registered are untouched.
///
/// - [bridgeBreadcrumbs] — when `true` (default), each breadcrumb in
///   `event.breadcrumbs` lands as its own OTel log. Set to `false`
///   if your OTel pipeline is high-traffic and breadcrumbs would
///   dominate.
/// - [loggerProvider] — defaults to `OTel.loggerProvider()` at first
///   use.
void installOTelBugsnagBridge(
  bs.BugsnagClient client, {
  bool bridgeBreadcrumbs = true,
  LoggerProvider? loggerProvider,
}) {
  client.addOnError((bs.BugsnagEvent event) {
    if (bugsnagBridgeSuppressed()) return true;
    final provider = loggerProvider ?? OTel.loggerProvider();
    final logger = provider.getLogger(_loggerName);
    final commonAttrs = _commonAttrs(event);

    for (final err in event.errors) {
      _emitError(
        logger: logger,
        event: event,
        error: err,
        commonAttrs: commonAttrs,
      );
    }

    if (bridgeBreadcrumbs) {
      for (final crumb in event.breadcrumbs) {
        _emitBreadcrumb(
          logger: logger,
          crumb: crumb,
          commonAttrs: commonAttrs,
        );
      }
    }

    // Always return true so Bugsnag still delivers the event.
    return true;
  });
}

void _emitError({
  required OTelLogger logger,
  required bs.BugsnagEvent event,
  required bs.BugsnagError error,
  required List<Attribute<Object>> commonAttrs,
}) {
  final attrs = <Attribute<Object>>[
    ...commonAttrs,
    OTel.attributeString('exception.type', error.errorClass),
    if (error.message != null)
      OTel.attributeString('exception.message', error.message!),
    OTel.attributeString(
      BugsnagBridgeSemantics.errorClass.key,
      error.errorClass,
    ),
    OTel.attributeString(
      BugsnagBridgeSemantics.errorType.key,
      error.type.name,
    ),
  ];

  logger.emit(
    severityNumber: _toOtelSeverity(event.severity),
    severityText: event.severity.name,
    body: error.message ?? error.errorClass,
    attributes: OTel.attributes(attrs),
  );
}

void _emitBreadcrumb({
  required OTelLogger logger,
  required bs.BugsnagBreadcrumb crumb,
  required List<Attribute<Object>> commonAttrs,
}) {
  final attrs = <Attribute<Object>>[
    ...commonAttrs,
    OTel.attributeString(
      BugsnagBridgeSemantics.breadcrumbMessage.key,
      crumb.message,
    ),
    OTel.attributeString(
      BugsnagBridgeSemantics.breadcrumbType.key,
      crumb.type.name,
    ),
  ];

  logger.emit(
    timeStamp: crumb.timestamp,
    severityNumber: Severity.INFO,
    severityText: 'info',
    body: crumb.message,
    attributes: OTel.attributes(attrs),
  );
}

List<Attribute<Object>> _commonAttrs(bs.BugsnagEvent event) {
  final attrs = <Attribute<Object>>[
    OTel.attributeBool(
      BugsnagBridgeSemantics.unhandled.key,
      event.unhandled,
    ),
    OTel.attributeString(
      BugsnagBridgeSemantics.severity.key,
      event.severity.name,
    ),
    OTel.attributeInt(
      BugsnagBridgeSemantics.breadcrumbCount.key,
      event.breadcrumbs.length,
    ),
  ];
  if (event.context != null) {
    attrs.add(OTel.attributeString(
      BugsnagBridgeSemantics.context.key,
      event.context!,
    ));
  }
  if (event.groupingHash != null) {
    attrs.add(OTel.attributeString(
      BugsnagBridgeSemantics.groupingHash.key,
      event.groupingHash!,
    ));
  }
  if (event.user.id != null) {
    attrs.add(OTel.attributeString(User.userId.key, event.user.id!));
  }
  if (event.user.email != null) {
    attrs.add(OTel.attributeString(User.userEmail.key, event.user.email!));
  }
  if (event.user.name != null) {
    attrs.add(OTel.attributeString(User.userFullName.key, event.user.name!));
  }
  return attrs;
}

Severity _toOtelSeverity(bs.BugsnagSeverity s) {
  switch (s) {
    case bs.BugsnagSeverity.error:
      return Severity.ERROR;
    case bs.BugsnagSeverity.warning:
      return Severity.WARN;
    case bs.BugsnagSeverity.info:
      return Severity.INFO;
  }
}
