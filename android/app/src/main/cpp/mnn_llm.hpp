#ifndef MNN_LLM_HPP
#define MNN_LLM_HPP

// MNN LLM API based on libllm.so symbols
// This header defines the interface matching the actual MNN LLM library

#include <string>
#include <vector>
#include <memory>
#include <ostream>

namespace MNN {
namespace Express {
class VARP;
}

namespace Transformer {

// Forward declarations
class LlmConfig;

/**
 * Llm - MNN Transformer LLM class
 *
 * 重要: response() 方法返回 void，生成的文本写入 ostream 参数
 *       这是与 libllm.so 实际 API 的关键区别
 */
class Llm {
public:
    // Create LLM from config path
    static Llm* createLLM(const std::string& configPath);

    // Load model
    bool load();

    // Generate response from text prompt
    // 输出写入 output ostream，无返回值
    // 参数: prompt, output stream, system prompt, max tokens
    void response(const std::string& prompt,
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