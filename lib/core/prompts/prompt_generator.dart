import 'prompt_types.dart';
import 'prompt_templates.dart';

class PromptGenerator {
  static PromptConfig generatePrompt({
    required PromptType type,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalParameters,
  }) {
    final systemPrompt = PromptTemplates.getSystemPrompt(type);
    String userPromptTemplate = PromptTemplates.getUserPromptTemplate(type);

    // Replace variables in the template
    variables.forEach((key, value) {
      userPromptTemplate = userPromptTemplate.replaceAll('{$key}', value);
    });

    return PromptConfig(
      systemPrompt: systemPrompt,
      userPrompt: userPromptTemplate,
      parameters: additionalParameters,
    );
  }

  static PromptConfig generateVoiceChatPrompt({
    required String message,
    Map<String, dynamic>? additionalParameters,
  }) {
    return generatePrompt(
      type: PromptType.voiceChat,
      variables: {'message': message},
      additionalParameters: additionalParameters,
    );
  }

  static PromptConfig generateTextChatPrompt({
    required String message,
    Map<String, dynamic>? additionalParameters,
  }) {
    return generatePrompt(
      type: PromptType.textChat,
      variables: {'message': message},
      additionalParameters: additionalParameters,
    );
  }

  static PromptConfig generateImagePrompt({
    required String description,
    Map<String, dynamic>? additionalParameters,
  }) {
    return generatePrompt(
      type: PromptType.imageGeneration,
      variables: {'description': description},
      additionalParameters: additionalParameters,
    );
  }
}
