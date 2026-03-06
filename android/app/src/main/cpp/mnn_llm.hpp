#ifndef MNN_LLM_HPP
#define MNN_LLM_HPP

// MNN LLM API based on libllm.so symbols
// This header defines the minimal interface needed for MNN LLM inference

#include <string>
#include <vector>
#include <memory>
#include <functional>

namespace MNN {
namespace Transformer {

// Forward declarations
class LlmConfig;

/**
 * Llm - MNN Transformer LLM class
 * Based on exported symbols from libllm.so
 */
class Llm {
public:
    // Create LLM from config path
    static Llm* createLLM(const std::string& configPath);

    // Load model
    bool load();

    // Generate response from text prompt
    // Returns generated text
    std::string response(const std::string& prompt,
                         std::ostream* output = nullptr,
                         const char* systemPrompt = nullptr,
                         int maxTokens = 256);

    // Tokenizer
    std::vector<int> tokenizer_encode(const std::string& text);
    std::string tokenizer_decode(int tokenId);

    // Reset context (clear KV cache)
    void reset();

    // Check if generation stopped
    bool stoped();
    bool is_stop(int tokenId);

    // Destroy instance
    static void destroy(Llm* llm);

    // Destructor
    ~Llm();

private:
    Llm(std::shared_ptr<LlmConfig> config);
    // Implementation details hidden
    void* impl_;
};

} // namespace Transformer
} // namespace MNN

#endif // MNN_LLM_HPP