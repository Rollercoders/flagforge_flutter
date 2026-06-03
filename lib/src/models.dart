/// Context passed to FlagForge when evaluating feature flags.
///
/// Both fields are optional. Omit [userId] and [attributes] to evaluate
/// flags without any targeting context.
class EvaluationContext {
  /// The identifier of the current user.
  final String? userId;

  /// Arbitrary key-value attributes used for attribute-based targeting rules.
  final Map<String, String>? attributes;

  /// Creates an [EvaluationContext].
  const EvaluationContext({this.userId, this.attributes});

  /// Serializes this context to a JSON-compatible map, omitting null fields.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (userId != null) map['userId'] = userId;
    if (attributes != null) map['attributes'] = attributes;
    return map;
  }
}
