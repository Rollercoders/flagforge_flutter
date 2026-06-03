class EvaluationContext {
  final String? userId;
  final Map<String, String>? attributes;

  const EvaluationContext({this.userId, this.attributes});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (userId != null) map['userId'] = userId;
    if (attributes != null) map['attributes'] = attributes;
    return map;
  }
}
