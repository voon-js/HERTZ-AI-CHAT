#ifndef LLAMA_WRAPPER_H
#define LLAMA_WRAPPER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Opaque handle types (caller doesn't see internals)
 */
typedef void* LlamaContext;

/**
 * Token callback function type.
 * Called for each generated token during inference.
 * 
 * @param token Pointer to token bytes (NOT null-terminated)
 * @param length Length of token in bytes
 * 
 * Thread-safe: may be called from background thread.
 */
typedef void (*TokenCallback)(const char* token, int length);

/**
 * Initialize llama.cpp model from GGUF file.
 * 
 * Must be called once before generation. Loads model into memory,
 * creates inference context. This is EXPENSIVE (consumes RAM).
 * 
 * @param model_path Full path to .gguf file (e.g., "/data/data/com.app/files/model.gguf")
 * @param n_threads  Number of CPU threads for inference (2-8 recommended)
 * 
 * @return Opaque context handle on success, NULL on error.
 *         On error, call llama_get_error() for message.
 * 
 * Example:
 *   LlamaContext ctx = llama_init_model("/path/to/model.gguf", 4);
 *   if (!ctx) {
 *     fprintf(stderr, "Error: %s\n", llama_get_error());
 *   }
 */
LlamaContext llama_init_model(const char* model_path, int n_threads);

/**
 * Generate tokens for a prompt with streaming callback.
 * 
 * BLOCKS until generation complete or max tokens reached.
 * For UI apps, call from background thread.
 * 
 * @param ctx        Context handle from llama_init_model()
 * @param prompt     Input text (e.g., "What is AI?")
 * @param max_tokens Maximum tokens to generate
 * @param callback   Called for each token: callback(token_ptr, token_len)
 *                   May be called from different thread - must be thread-safe.
 * 
 * @return 0 on success, -1 on error (check llama_get_error())
 * 
 * Example:
 *   void my_callback(const char* token, int len) {
 *     fwrite(token, 1, len, stdout);
 *     fflush(stdout);
 *   }
 *   
 *   int status = llama_generate(ctx, "Hello", 100, my_callback);
 */
int llama_generate(
    LlamaContext ctx,
    const char* prompt,
    int max_tokens,
    TokenCallback callback
);

/**
 * Request the currently running generation pass to stop as soon as possible.
 * Safe to call from another thread while llama_generate() is running.
 */
void llama_stop_generation(void);

/**
 * Free model context and all associated resources.
 * 
 * Must be called when done (before app exit, on user logout, etc.)
 * Safe to call multiple times (no-op if already freed).
 * 
 * @param ctx Context handle from llama_init_model()
 */
void llama_free_context(LlamaContext ctx);

/**
 * Get most recent error message.
 * 
 * Returns static buffer (valid until next call).
 * Check after init_model() or generate() fail.
 * 
 * @return Error message string
 */
const char* llama_get_error(void);

#ifdef __cplusplus
}
#endif

#endif // LLAMA_WRAPPER_H
