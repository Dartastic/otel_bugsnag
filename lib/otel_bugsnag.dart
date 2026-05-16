// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

/// OpenTelemetry bridge for `package:bugsnag_flutter`.
///
/// Call `installOTelBugsnagBridge(bugsnag)` once after
/// `bugsnag.start(...)`. Every error event Bugsnag captures (handled
/// `notify` calls plus unhandled crashes) lands as an OTel log
/// record carrying `exception.*` attributes, with each attached
/// breadcrumb emitted as its own INFO log. Records inherit
/// `trace_id` / `span_id` from `Context.current` so errors caught
/// inside `tracer.withSpan` blocks attach to that span.
library;

export 'src/bugsnag_semantics.dart';
export 'src/otel_bugsnag_bridge.dart';
export 'src/otel_bugsnag_suppression.dart';
