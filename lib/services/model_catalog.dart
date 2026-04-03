class ModelCatalogEntry {
  final String id;
  final String name;
  final String filename;
  final String url;
  final String description;

  const ModelCatalogEntry({
    required this.id,
    required this.name,
    required this.filename,
    required this.url,
    required this.description,
  });
}

class ModelCatalog {
  static const String defaultModelId = 'tinyllama_q4';

  static const List<ModelCatalogEntry> models = [
    ModelCatalogEntry(
      id: defaultModelId,
      name: 'TinyLlama Q4',
      filename: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      url:
          'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      description: 'Fast, lightweight on-device model (1.1B parameters)',
    ),
    ModelCatalogEntry(
      id: 'qwen2_5_3b_instruct_q4',
      name: 'Qwen2.5 3B Instruct Q4',
      filename: 'Qwen2.5-3B-Instruct-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
      description:
          'Stronger general chat model with a good size-to-quality balance (3B parameters)',
    ),
    ModelCatalogEntry(
      id: 'llama_3_2_1b_instruct_q4',
      name: 'Llama 3.2 1B Instruct Q4',
      filename: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      url:
        'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      description:
        'Fast fallback model with low RAM usage and good mobile performance (1B parameters)',
    ),
    ModelCatalogEntry(
      id: 'phi_3_5_mini_instruct_q4',
      name: 'Phi 3.5 Mini Instruct Q4',
      filename: 'Phi-3.5-mini-instruct-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
      description:
          'Compact model with strong reasoning and coding performance for its size (3.8B parameters)',
    ),
    ModelCatalogEntry(
      id: 'qwen2_5_coder_1_5b_instruct_q4',
      name: 'Qwen2.5 Coder 1.5B Instruct Q4',
      filename: 'Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf',
      description:
          'Lightweight coding-focused model for code generation, debugging, and technical tasks (1.5B parameters)',
    ),
    ModelCatalogEntry(
      id: 'gemma_2_2b_it_q4',
      name: 'Gemma 2 2B It Q4',
      filename: 'gemma-2-2b-it-Q4_K_M.gguf',
      url:
          'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
      description:
          'Balanced general-purpose conversational model with good quality-to-size ratio (2B parameters)',
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
}