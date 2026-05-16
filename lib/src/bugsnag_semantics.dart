// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Attribute keys for the Bugsnag → OTel bridge.
///
/// `bugsnag.*` keys are package-local — there is no upstream OTel
/// semantic convention for Bugsnag's event model yet. Stable across
/// the 0.x line.
enum BugsnagBridgeSemantics implements OTelSemantic {
  /// `bugsnag.context` — `BugsnagEvent.context`, the active context
  /// at error capture time (e.g. the route name).
  context('bugsnag.context'),

  /// `bugsnag.unhandled` — `true` for unhandled crashes,
  /// `false` for handled `notify()` calls.
  unhandled('bugsnag.unhandled'),

  /// `bugsnag.grouping_hash` — overridden grouping hash supplied
  /// via `event.groupingHash`.
  groupingHash('bugsnag.grouping_hash'),

  /// `bugsnag.error.class` — `BugsnagError.errorClass` (e.g.
  /// `StateError`, `NullPointerException`).
  errorClass('bugsnag.error.class'),

  /// `bugsnag.error.type` — platform (`dart`, `android`, `cocoa`,
  /// `c`).
  errorType('bugsnag.error.type'),

  /// `bugsnag.severity` — `BugsnagSeverity` enum value (`error`,
  /// `warning`, `info`).
  severity('bugsnag.severity'),

  /// `bugsnag.session.id` — Bugsnag session identifier active at
  /// capture time.
  sessionId('bugsnag.session.id'),

  /// `bugsnag.breadcrumb.message` — text of a breadcrumb when
  /// emitted as its own log record.
  breadcrumbMessage('bugsnag.breadcrumb.message'),

  /// `bugsnag.breadcrumb.type` — `BugsnagBreadcrumbType` name
  /// (`navigation`, `request`, `process`, `log`, `user`, `state`,
  /// `error`, `manual`).
  breadcrumbType('bugsnag.breadcrumb.type'),

  /// `bugsnag.breadcrumb.count` — number of breadcrumbs attached
  /// to the surrounding event log record.
  breadcrumbCount('bugsnag.breadcrumb.count'),

  /// `bugsnag.feature_flag.<name>` — feature flag value attached
  /// to the event. Variant is the attribute value, or `""` when the
  /// flag has no variant.
  featureFlagPrefix('bugsnag.feature_flag.');

  const BugsnagBridgeSemantics(this.key);

  @override
  final String key;

  @override
  String toString() => key;
}
