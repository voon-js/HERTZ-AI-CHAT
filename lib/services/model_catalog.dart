class ModelCatalogEntry {
  final String id;
  final String name;
  final String baseModelName;
  final String filename;
  final String url;
  final String description;
  final String modelSize;
  final bool isHeavy;
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
    required this.quantization,
    required this.parameters,
    required this.contextTokens,
    required this.recommendedRam,
  });
}

class ModelCatalog {
  static const String defaultModelId = 'tinyllama_q4';

  static const List<ModelCatalogEntry> models = [
    ModelCatalogEntry(
      id: defaultModelId,
      name: 'Hertz Flow',
      baseModelName: 'TinyLlama-1.1B-Chat-v1.0',
      filename: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      url:
          'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      description:
          'Ultra-light general model for quick responses and lower-end devices',
        modelSize: '0.67 GB',
      quantization: 'Q4_K_M',
      parameters: '1.1B',
      contextTokens: '2K token context window',
      recommendedRam: '2-3 GB free',
    ),
    ModelCatalogEntry(
      id: 'llama_3_2_1b_instruct_q4',
      name: 'Hertz Spark',
      baseModelName: 'Llama-3.2-1B-Instruct',
      filename: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      description:
          'Compact assistant model focused on speed and minimal memory usage',
        modelSize: '0.81 GB',
      quantization: 'Q4_K_M',
      parameters: '1B',
      contextTokens: '8K token context window',
      recommendedRam: '2-3 GB free',
    ),
    ModelCatalogEntry(
      id: 'qwen2_5_coder_1_5b_instruct_q4',
      name: 'Hertz Forge',
      baseModelName: 'Qwen2.5-Coder-1.5B-Instruct',
      filename: 'Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf',
      description:
          'Coding-focused model for code generation, debugging, and technical tasks',
        modelSize: '0.99 GB',
      quantization: 'Q4_K_M',
      parameters: '1.5B',
      contextTokens: '32K token context window',
      recommendedRam: '3-4 GB free',
    ),
    ModelCatalogEntry(
      id: 'gemma_2_2b_it_q4',
      name: 'Hertz Pulse',
      baseModelName: 'Gemma-2-2B-It',
      filename: 'gemma-2-2b-it-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
      description:
          'General-purpose conversational model with steady quality and efficient size',
        modelSize: '1.71 GB',
      quantization: 'Q4_K_M',
      parameters: '2B',
      contextTokens: '8K token context window',
      recommendedRam: '4-5 GB free',
    ),
    ModelCatalogEntry(
      id: 'phi_3_5_mini_instruct_q4',
      name: 'Hertz Focus',
      baseModelName: 'Phi-3.5-mini-instruct',
      filename: 'Phi-3.5-mini-instruct-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
      description:
          'Compact high-capability model for clear reasoning and concise answers',
        modelSize: '2.39 GB',
      quantization: 'Q4_K_M',
      parameters: '3.8B',
      contextTokens: '128K token context window',
      recommendedRam: '5-6 GB free',
    ),
    ModelCatalogEntry(
      id: 'qwen2_5_3b_instruct_q4',
      name: 'Hertz Prime',
      baseModelName: 'Qwen2.5-3B-Instruct',
      filename: 'Qwen2.5-3B-Instruct-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
      description:
          'Strong all-around chat model with a great quality-to-size balance',
        modelSize: '1.93 GB',
      quantization: 'Q4_K_M',
      parameters: '3B',
      contextTokens: '32K token context window',
      recommendedRam: '5-6 GB free',
    ),
    ModelCatalogEntry(
      id: 'qwen2_5_7b_instruct_q4',
      name: 'Hertz Apex',
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