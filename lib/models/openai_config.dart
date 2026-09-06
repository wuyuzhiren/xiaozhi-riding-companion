class OpenAIConfig {
  final String id;
  final String name;
  final String apiUrl; // e.g. https://api.siliconflow.cn/v1
  final String apiKey;
  final String model; // e.g. deepseek-ai/DeepSeek-V3
  final String ttsModel; // e.g. FunAudioLLM/CosyVoice2-0.5B
  final String ttsVoice; // e.g. FunAudioLLM/CosyVoice2-0.5B:claire
  final bool voiceReply; // whether to speak the reply aloud

  OpenAIConfig({
    required this.id,
    required this.name,
    required this.apiUrl,
    required this.apiKey,
    required this.model,
    required this.ttsModel,
    required this.ttsVoice,
    this.voiceReply = true,
  });

  factory OpenAIConfig.fromJson(Map<String, dynamic> json) {
    return OpenAIConfig(
      id: json['id'],
      name: json['name'] ?? 'SiliconFlow',
      apiUrl: json['apiUrl'] ?? 'https://api.siliconflow.cn/v1',
      apiKey: json['apiKey'] ?? '',
      model: json['model'] ?? '',
      ttsModel: json['ttsModel'] ?? 'FunAudioLLM/CosyVoice2-0.5B',
      ttsVoice: json['ttsVoice'] ?? 'FunAudioLLM/CosyVoice2-0.5B:claire',
      voiceReply: json['voiceReply'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'apiUrl': apiUrl,
      'apiKey': apiKey,
      'model': model,
      'ttsModel': ttsModel,
      'ttsVoice': ttsVoice,
      'voiceReply': voiceReply,
    };
  }
}
