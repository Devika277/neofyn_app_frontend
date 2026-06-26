class CustomerParam {
  final String paramName;
  final String dataType;
  final bool optional;
  final int? minLength;
  final int? maxLength;
  final String? regex;
  final String? description;

  CustomerParam({
    required this.paramName,
    required this.dataType,
    required this.optional,
    this.minLength,
    this.maxLength,
    this.regex,
    this.description,
  });

  factory CustomerParam.fromJson(Map<String, dynamic> json) {
    return CustomerParam(
      paramName: json['paramName'] ?? '',
      dataType: json['dataType'] ?? 'string',
      optional: json['optional'] ?? false,
      minLength: json['minLength'],
      maxLength: json['maxLength'],
      regex: json['regex'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paramName': paramName,
      'dataType': dataType,
      'optional': optional,
      'minLength': minLength,
      'maxLength': maxLength,
      'regex': regex,
      'description': description,
    };
  }
}