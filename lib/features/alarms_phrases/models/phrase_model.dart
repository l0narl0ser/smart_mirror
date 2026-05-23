class PhraseModel {
  final String id;
  String text;

  PhraseModel({
    required this.id,
    required this.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
    };
  }

  factory PhraseModel.fromJson(Map<String, dynamic> json) {
    return PhraseModel(
      id: json['id'] as String,
      text: json['text'] as String,
    );
  }
}
