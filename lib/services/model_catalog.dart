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