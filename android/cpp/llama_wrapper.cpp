#include "llama_wrapper.h"
#include "llama.cpp/include/llama.h"

#include <android/log.h>

#include <atomic>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <vector>

#define LOG_TAG "LlamaWrapper"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static thread_local char g_error_buffer[512] = {0};
static std::once_flag g_backend_init_once;
static std::atomic<int> g_active_contexts{0};

struct LlamaContextWrapper {
    llama_model * model = nullptr;
    llama_context * ctx = nullptr;
    const llama_vocab * vocab = nullptr;
    llama_sampler * sampler = nullptr;

    std::mutex mutex;
    std::atomic<bool> is_generating{false};
};

static bool tokenize_prompt(
    const llama_vocab * vocab,
    const char * prompt,
    std::vector<llama_token> & out_tokens
) {
    const int32_t text_len = static_cast<int32_t>(std::strlen(prompt));

    int32_t n = llama_tokenize(vocab, prompt, text_len, nullptr, 0, true, true);
    if (n == INT32_MIN) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Tokenization overflow");
        return false;
    }
    if (n < 0) {
        n = -n;
    }
    if (n <= 0) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Prompt tokenization produced no tokens");
        return false;
    }

    out_tokens.resize(static_cast<size_t>(n));
    const int32_t actual = llama_tokenize(
        vocab,
        prompt,
        text_len,
        out_tokens.data(),
        n,
        true,
        true
    );

    if (actual <= 0) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "llama_tokenize failed");
        return false;
    }

    out_tokens.resize(static_cast<size_t>(actual));
    return true;
}

extern "C" {

LlamaContext llama_init_model(const char * model_path, int n_threads) {
    if (!model_path || model_path[0] == '\0') {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "model_path is null or empty");
        return nullptr;
    }

    if (n_threads < 1) {
        n_threads = 4;
    }

    std::call_once(g_backend_init_once, []() {
        llama_backend_init();
    });

    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;

    llama_model * model = llama_model_load_from_file(model_path, model_params);
    if (!model) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Failed to load model: %s", model_path);
        return nullptr;
    }

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048;
    ctx_params.n_batch = 512;
    ctx_params.n_ubatch = 512;
    ctx_params.n_seq_max = 1;
    ctx_params.n_threads = n_threads;
    ctx_params.n_threads_batch = n_threads;

    llama_context * ctx = llama_init_from_model(model, ctx_params);
    if (!ctx) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Failed to create llama context");
        llama_model_free(model);
        return nullptr;
    }

    llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
    llama_sampler * sampler = llama_sampler_chain_init(sparams);
    if (!sampler) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Failed to create sampler");
        llama_free(ctx);
        llama_model_free(model);
        return nullptr;
    }

    // Simple, stable default sampling chain for mobile usage.
    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9f, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.8f));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(1234));

    const llama_vocab * vocab = llama_model_get_vocab(model);
    if (!vocab) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Failed to get model vocab");
        llama_sampler_free(sampler);
        llama_free(ctx);
        llama_model_free(model);
        return nullptr;
    }

    auto * wrapper = new LlamaContextWrapper();
    wrapper->model = model;
    wrapper->ctx = ctx;
    wrapper->vocab = vocab;
    wrapper->sampler = sampler;

    g_active_contexts.fetch_add(1);
    LOGI("Model initialized with %d threads", n_threads);
    return reinterpret_cast<LlamaContext>(wrapper);
}

int llama_generate(
    LlamaContext ctx,
    const char * prompt,
    int max_tokens,
    TokenCallback callback
) {
    if (!ctx) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Context is null");
        return -1;
    }
    if (!prompt || prompt[0] == '\0') {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Prompt is null or empty");
        return -1;
    }
    if (!callback) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Callback is null");
        return -1;
    }
    if (max_tokens < 1) {
        max_tokens = 1;
    }

    auto * wrapper = reinterpret_cast<LlamaContextWrapper *>(ctx);

    bool expected = false;
    if (!wrapper->is_generating.compare_exchange_strong(expected, true)) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Generation already in progress");
        return -1;
    }

    int rc = 0;

    try {
        std::lock_guard<std::mutex> lock(wrapper->mutex);

        // Reset state for a fresh completion pass.
        llama_memory_clear(llama_get_memory(wrapper->ctx), true);
        llama_sampler_reset(wrapper->sampler);

        std::vector<llama_token> prompt_tokens;
        if (!tokenize_prompt(wrapper->vocab, prompt, prompt_tokens)) {
            rc = -1;
        } else {
            llama_batch batch = llama_batch_init(static_cast<int32_t>(prompt_tokens.size()), 0, 1);
            batch.n_tokens = static_cast<int32_t>(prompt_tokens.size());

            for (int i = 0; i < batch.n_tokens; ++i) {
                batch.token[i] = prompt_tokens[static_cast<size_t>(i)];
                batch.pos[i] = i;
                batch.n_seq_id[i] = 1;
                batch.seq_id[i][0] = 0;
                batch.logits[i] = (i == batch.n_tokens - 1);
            }

            const int decode_prompt_rc = llama_decode(wrapper->ctx, batch);
            llama_batch_free(batch);

            if (decode_prompt_rc != 0) {
                std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Prompt decode failed: %d", decode_prompt_rc);
                rc = -1;
            }

            for (int i = 0; rc == 0 && i < max_tokens; ++i) {
                const llama_token token = llama_sampler_sample(wrapper->sampler, wrapper->ctx, -1);

                if (llama_vocab_is_eog(wrapper->vocab, token)) {
                    break;
                }

                char piece[1024] = {0};
                const int32_t n_piece = llama_token_to_piece(
                    wrapper->vocab,
                    token,
                    piece,
                    static_cast<int32_t>(sizeof(piece)),
                    0,
                    true
                );

                if (n_piece > 0) {
                    callback(piece, n_piece);
                }

                llama_sampler_accept(wrapper->sampler, token);

                llama_batch one = llama_batch_init(1, 0, 1);
                one.n_tokens = 1;
                one.token[0] = token;
                one.pos[0] = static_cast<llama_pos>(prompt_tokens.size() + static_cast<size_t>(i));
                one.n_seq_id[0] = 1;
                one.seq_id[0][0] = 0;
                one.logits[0] = true;

                const int decode_token_rc = llama_decode(wrapper->ctx, one);
                llama_batch_free(one);

                if (decode_token_rc != 0) {
                    std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Token decode failed at step %d: %d", i, decode_token_rc);
                    rc = -1;
                }
            }
        }
    } catch (...) {
        std::snprintf(g_error_buffer, sizeof(g_error_buffer), "Unhandled exception in generation");
        rc = -1;
    }

    wrapper->is_generating = false;
    return rc;
}

void llama_free_context(LlamaContext ctx) {
    if (!ctx) {
        return;
    }

    auto * wrapper = reinterpret_cast<LlamaContextWrapper *>(ctx);

    if (wrapper->sampler) {
        llama_sampler_free(wrapper->sampler);
        wrapper->sampler = nullptr;
    }

    if (wrapper->ctx) {
        llama_free(wrapper->ctx);
        wrapper->ctx = nullptr;
    }

    if (wrapper->model) {
        llama_model_free(wrapper->model);
        wrapper->model = nullptr;
    }

    delete wrapper;

    const int remaining = g_active_contexts.fetch_sub(1) - 1;
    if (remaining == 0) {
        llama_backend_free();
    }
}

const char * llama_get_error(void) {
    return g_error_buffer[0] ? g_error_buffer : "No error";
}

} // extern "C"
