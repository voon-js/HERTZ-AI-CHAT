class ModelCatalogEntry {
  final String id;
  final String name;
  final String baseModelName;
  final String filename;
  final String url;
  final String description;
  final String modelSize;
  final bool isHeavy;
  final bool isCoding;
  final String quantization;
  final String parameters;
  final String contextTokens;
  final String recommendedRam;

  const ModelCatalogEntry({
    required this.id,
    required this.name,
    required this.baseModelName,
    required this.filename,
    required this.url,
    required this.description,
    required this.modelSize,
    this.isHeavy = false,
    this.isCoding = false,
    required this.quantization,
    required this.parameters,
    required this.contextTokens,
    required this.recommendedRam,
  });

  String get tierName {
    const prefix = 'Hertz ';
    if (name.startsWith(prefix) && name.length > prefix.length) {
      return name.substring(prefix.length);
    }
    return name;
  }
}

class ModelCatalog {
  static const String defaultModelId = 'gemma_3_1b_it_q4';

  static const List<ModelCatalogEntry> models = [
    ModelCatalogEntry(
      id: defaultModelId,
      name: 'Hertz Lite',
      baseModelName: 'Gemma-3-1B-IT',
      filename: 'google_gemma-3-1b-it-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/google_gemma-3-1b-it-GGUF/resolve/main/google_gemma-3-1b-it-Q4_K_M.gguf',
      description:
          'Best-in-class compact 1B model for high quality on-device responses',
        modelSize: '0.81 GB',
      quantization: 'Q4_K_M',
      parameters: '1B',
      contextTokens: '32K token context window',
      recommendedRam: '3-4 GB free',
    ),
    ModelCatalogEntry(
      id: 'gemma_2_2b_it_q4',
      name: 'Hertz Core',
      baseModelName: 'Gemma-2-2B-It',
      filename: 'gemma-2-2b-it-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
      description:
          'Balanced 2B general-purpose model with strong quality-per-memory',
        modelSize: '1.71 GB',
      quantization: 'Q4_K_M',
      parameters: '2B',
      contextTokens: '8K token context window',
      recommendedRam: '4-5 GB free',
    ),
    ModelCatalogEntry(
      id: 'qwen2_5_3b_instruct_q4',
      name: 'Hertz Plus',
      baseModelName: 'Qwen2.5-3B-Instruct',
      filename: 'Qwen2.5-3B-Instruct-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
      description:
          'High-quality 3B all-around model for stronger reasoning and chat',
        modelSize: '1.93 GB',
      quantization: 'Q4_K_M',
      parameters: '3B',
      contextTokens: '32K token context window',
      recommendedRam: '5-6 GB free',
    ),
    ModelCatalogEntry(
      id: 'qwen2_5_coder_7b_instruct_q4',
      name: 'Hertz Forge',
      baseModelName: 'Qwen2.5-Coder-7B-Instruct',
      filename: 'Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf',
      description:
          'Coding-specialist model for code generation, debugging, and technical tasks',
      modelSize: '4.79 GB',
      isHeavy: true,
      isCoding: true,
      quantization: 'Q4_K_M',
      parameters: '7B',
      contextTokens: '128K token context window',
      recommendedRam: '8-10 GB free',
    ),
    ModelCatalogEntry(
      id: 'qwen2_5_7b_instruct_q4',
      name: 'Hertz Ultra',
      baseModelName: 'Qwen2.5-7B-Instruct',
      filename: 'Qwen2.5-7B-Instruct-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf',
      description:
          'High-capability large model for stronger reasoning and richer responses',
      isHeavy: true,
        modelSize: '4.68 GB',
      quantization: 'Q4_K_M',
      parameters: '7B',
      contextTokens: '128K token context window',
      recommendedRam: '8-10 GB free',
    ),
    ModelCatalogEntry(
      id: 'qwen2_5_8b_instruct_q4',
      name: 'Hertz Apex',
      baseModelName: 'Qwen2.5-7B-Instruct',
      filename: 'Qwen2.5-7B-Instruct-Q5_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q5_K_M.gguf',
      description:
          'Top-quality high-precision 7B profile for the strongest Hertz chat quality',
      isHeavy: true,
      modelSize: '5.43 GB',
      quantization: 'Q5_K_M',
      parameters: '7B',
      contextTokens: '128K token context window',
      recommendedRam: '10-12 GB free',
    ),
  ];

  static ModelCatalogEntry get defaultModel => models.firstWhere(
        (model) => model.id == defaultModelId,
        orElse: () => models.first,
      );

  static ModelCatalogEntry byId(String id) => models.firstWhere(
        (model) => model.id == id,
        orElse: () => defaultModel,
      );

  static ModelCatalogEntry byName(String name) => models.firstWhere(
        (model) => model.name == name,
        orElse: () => defaultModel,
      );
}