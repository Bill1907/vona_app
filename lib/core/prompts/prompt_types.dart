class PromptConfig {
  final String systemPrompt;
  final String userPrompt;
  final Map<String, dynamic>? parameters;

  const PromptConfig({
    required this.systemPrompt,
    required this.userPrompt,
    this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'systemPrompt': systemPrompt,
        'userPrompt': userPrompt,
        'parameters': parameters,
      };
}

enum PromptType {
  voiceChat,
  textChat,
  imageGeneration,
}
