import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../prompts/prompt_types.dart';

class PromptStorageService {
  static final PromptStorageService instance = PromptStorageService._init();

  PromptStorageService._init();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _promptFile async {
    final path = await _localPath;
    return File('$path/prompts.txt');
  }

  // 프롬프트 저장
  Future<File> savePrompt(PromptConfig prompt, {String? name}) async {
    final file = await _promptFile;
    final prompts = await readAllPrompts();

    // 새로운 프롬프트 추가
    prompts[name ?? DateTime.now().toIso8601String()] = prompt.toJson();

    // JSON 형식으로 저장
    return file.writeAsString(json.encode(prompts));
  }

  // 모든 프롬프트 읽기
  Future<Map<String, dynamic>> readAllPrompts() async {
    try {
      final file = await _promptFile;

      if (!await file.exists()) {
        return {};
      }

      final contents = await file.readAsString();
      return contents.isEmpty
          ? {}
          : json.decode(contents) as Map<String, dynamic>;
    } catch (e) {
      print('Error reading prompts: $e');
      return {};
    }
  }

  // 특정 이름의 프롬프트 읽기
  Future<PromptConfig?> readPrompt(String name) async {
    final prompts = await readAllPrompts();
    final promptJson = prompts[name];

    if (promptJson == null) return null;

    return PromptConfig(
      systemPrompt: promptJson['systemPrompt'],
      userPrompt: promptJson['userPrompt'],
      parameters: promptJson['parameters'],
    );
  }

  // 프롬프트 삭제
  Future<void> deletePrompt(String name) async {
    final prompts = await readAllPrompts();
    prompts.remove(name);

    final file = await _promptFile;
    await file.writeAsString(json.encode(prompts));
  }

  // 프롬프트 업데이트
  Future<void> updatePrompt(String name, PromptConfig newPrompt) async {
    final prompts = await readAllPrompts();
    prompts[name] = newPrompt.toJson();

    final file = await _promptFile;
    await file.writeAsString(json.encode(prompts));
  }

  // 프롬프트 검색
  Future<Map<String, PromptConfig>> searchPrompts(String keyword) async {
    final allPrompts = await readAllPrompts();
    final Map<String, PromptConfig> results = {};

    allPrompts.forEach((name, promptJson) {
      if (name.toLowerCase().contains(keyword.toLowerCase()) ||
          promptJson['systemPrompt']
              .toString()
              .toLowerCase()
              .contains(keyword.toLowerCase()) ||
          promptJson['userPrompt']
              .toString()
              .toLowerCase()
              .contains(keyword.toLowerCase())) {
        results[name] = PromptConfig(
          systemPrompt: promptJson['systemPrompt'],
          userPrompt: promptJson['userPrompt'],
          parameters: promptJson['parameters'],
        );
      }
    });

    return results;
  }

  // 백업 생성
  Future<File> createBackup() async {
    final path = await _localPath;
    final timestamp = DateTime.now().toIso8601String();
    final backupFile = File('$path/prompts_backup_$timestamp.txt');

    final prompts = await readAllPrompts();
    return backupFile.writeAsString(json.encode(prompts));
  }

  // 백업으로부터 복원
  Future<void> restoreFromBackup(String backupPath) async {
    final backupFile = File(backupPath);
    if (await backupFile.exists()) {
      final contents = await backupFile.readAsString();
      final file = await _promptFile;
      await file.writeAsString(contents);
    }
  }
}
