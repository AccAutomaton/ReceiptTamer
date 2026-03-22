#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <chrono>
#include <fstream>
#include <sstream>
#include <cstdlib>
#include <cctype>
#include <regex>
#include "mnn_llm.hpp"

#define LOG_TAG "MnnJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

/**
 * MnnLlmContext - MNN LLM 推理上下文
 *
 * 使用真正的 MNN LLM 进行推理
 */
class MnnLlmContext {
public:
    MnnLlmContext() : llm_(nullptr), initialized_(false), nThreads_(4) {}

    ~MnnLlmContext() {
        dispose();
    }

    bool loadModel(const std::string& modelDir, int nThreads) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (initialized_) {
            LOGE("Model already loaded");
            return false;
        }

        auto totalStart = std::chrono::high_resolution_clock::now();

        LOGI("========== MNN LLM Model Loading ==========");
        LOGI("Model directory: %s", modelDir.c_str());
        LOGI("Threads: %d", nThreads);

        // Check if model directory exists
        std::string configPath = modelDir + "/llm_config.json";
        std::ifstream configFile(configPath);
        if (!configFile.good()) {
            LOGE("Config file not found: %s", configPath.c_str());
            return false;
        }
        configFile.close();

        // Check model files
        std::string modelPath = modelDir + "/llm.mnn";
        std::string weightPath = modelDir + "/llm.mnn.weight";

        std::ifstream modelFile(modelPath);
        if (!modelFile.good()) {
            LOGE("Model file not found: %s", modelPath.c_str());
            return false;
        }
        modelFile.close();

        std::ifstream weightFile(weightPath);
        if (!weightFile.good()) {
            LOGE("Weight file not found: %s", weightPath.c_str());
            return false;
        }
        weightFile.close();

        // Create LLM instance
        LOGI("Creating MNN LLM instance...");
        llm_ = MNN::Transformer::Llm::createLLM(configPath);
        if (!llm_) {
            LOGE("Failed to create MNN LLM instance");
            return false;
        }

        // Load model weights
        LOGI("Loading model weights...");
        if (!llm_->load()) {
            LOGE("Failed to load model weights");
            MNN::Transformer::Llm::destroy(llm_);
            llm_ = nullptr;
            return false;
        }

        // Store paths
        modelDir_ = modelDir;
        nThreads_ = nThreads;
        initialized_ = true;

        auto totalEnd = std::chrono::high_resolution_clock::now();
        auto totalMs = std::chrono::duration_cast<std::chrono::milliseconds>(totalEnd - totalStart).count();

        LOGI("========== MNN LLM Model Loaded ==========");
        LOGI("[DIAG] Total loading time: %lldms", (long long)totalMs);

        return true;
    }

    std::string generate(const std::string& prompt, int maxTokens, float temperature, float topP) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (!initialized_ || !llm_) {
            LOGE("Model not initialized");
            return "";
        }

        LOGI("========== MNN LLM Generation Start ==========");
        LOGI("Prompt length: %zu chars, maxTokens: %d", prompt.length(), maxTokens);

        auto genStart = std::chrono::high_resolution_clock::now();

        // Format prompt in Qwen chat format
        std::string formattedPrompt = "<|im_start|>user\n" + prompt + "<|im_end|>\n<|im_start|>assistant\n";
        LOGI("[DIAG] Formatted prompt length: %zu", formattedPrompt.length());

        // Use string stream to capture output
        std::stringstream ss;

        // Call MNN LLM for inference
        std::string retVal = llm_->response(formattedPrompt, &ss, nullptr, maxTokens);

        auto genEnd = std::chrono::high_resolution_clock::now();
        auto genMs = std::chrono::duration_cast<std::chrono::milliseconds>(genEnd - genStart).count();

        LOGI("========== MNN LLM Generation Complete ==========");
        LOGI("[DIAG] Generation time: %lldms", (long long)genMs);

        // Get the response from stream (this has the actual content)
        std::string rawResponse = ss.str();
        LOGI("[DIAG] Response length: %zu", rawResponse.length());
        LOGI("[DIAG] Response preview: %s", rawResponse.substr(0, 200).c_str());

        // Reset LLM context to clear KV cache
        llm_->reset();

        // Extract JSON from LLM response
        std::string jsonResult = extractJsonFromResponse(rawResponse);
        LOGI("[DIAG] Extracted JSON length: %zu", jsonResult.length());

        return jsonResult;
    }

    void dispose() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (llm_) {
            LOGI("Destroying MNN LLM instance...");
            MNN::Transformer::Llm::destroy(llm_);
            llm_ = nullptr;
        }
        initialized_ = false;
        LOGI("MnnLlmContext disposed");
    }

    bool isInitialized() const {
        return initialized_ && llm_ != nullptr;
    }

private:
    /**
     * Extract JSON from LLM response
     * LLM may return:
     * 1. Direct JSON: {"shopName":"xxx",...}
     * 2. Markdown code block: ```json\n{...}\n```
     * 3. Mixed text with JSON embedded
     * 4. Incomplete/truncated JSON
     */
    std::string extractJsonFromResponse(const std::string& response) {
        if (response.empty()) {
            return R"({"error": "Empty response from LLM"})";
        }

        std::string cleaned = response;

        // Step 1: Remove markdown code block markers
        // Remove leading ```json or ```
        size_t pos = 0;
        while (pos < cleaned.length()) {
            if (cleaned.substr(pos, 7) == "```json") {
                cleaned = cleaned.substr(0, pos) + cleaned.substr(pos + 7);
            } else if (cleaned.substr(pos, 3) == "```") {
                cleaned = cleaned.substr(0, pos) + cleaned.substr(pos + 3);
            } else {
                break;
            }
        }

        // Remove trailing ``` if present
        size_t lastBackticks = cleaned.rfind("```");
        if (lastBackticks != std::string::npos && lastBackticks > 0) {
            cleaned = cleaned.substr(0, lastBackticks);
        }

        // Step 2: Find first complete JSON object {...}
        size_t startPos = cleaned.find('{');
        if (startPos != std::string::npos) {
            int braceCount = 0;
            size_t endPos = std::string::npos;

            for (size_t i = startPos; i < cleaned.length(); i++) {
                if (cleaned[i] == '{') {
                    braceCount++;
                } else if (cleaned[i] == '}') {
                    braceCount--;
                    if (braceCount == 0) {
                        endPos = i;
                        break;
                    }
                }
            }

            if (endPos != std::string::npos) {
                std::string jsonStr = cleaned.substr(startPos, endPos - startPos + 1);
                // Clean up duplicate keys and validate
                std::string cleanedJson = cleanDuplicateKeys(jsonStr);
                if (isValidJson(cleanedJson)) {
                    return cleanedJson;
                }
            }
        }

        // Fallback
        return R"({"error": "Failed to extract JSON from LLM response"})";
    }

    /**
     * Remove duplicate keys from JSON (keep first occurrence)
     */
    std::string cleanDuplicateKeys(const std::string& json) {
        // Simple approach: just return the first complete JSON object
        // The LLM may generate multiple values for same key, we take the first complete one
        return json;
    }

    bool isValidJson(const std::string& str) {
        // Simple validation: check if it starts with { and ends with }
        std::string trimmed = trim(str);
        if (trimmed.empty() || trimmed.front() != '{' || trimmed.back() != '}') {
            return false;
        }

        // Check balanced braces
        int braceCount = 0;
        bool inString = false;
        for (size_t i = 0; i < trimmed.length(); i++) {
            char c = trimmed[i];
            if (c == '"' && (i == 0 || trimmed[i-1] != '\\')) {
                inString = !inString;
            }
            if (!inString) {
                if (c == '{') braceCount++;
                else if (c == '}') braceCount--;
            }
        }
        return braceCount == 0;
    }

    std::string trim(const std::string& str) {
        size_t start = str.find_first_not_of(" \t\n\r");
        if (start == std::string::npos) return "";
        size_t end = str.find_last_not_of(" \t\n\r");
        return str.substr(start, end - start + 1);
    }

    std::string escapeJson(const std::string& str) {
        std::string result;
        for (char c : str) {
            switch (c) {
                case '"': result += "\\\""; break;
                case '\\': result += "\\\\"; break;
                case '\n': result += "\\n"; break;
                case '\r': result += "\\r"; break;
                case '\t': result += "\\t"; break;
                default: result += c; break;
            }
        }
        return result;
    }

    /**
     * Sanitize string to valid UTF-8 for JNI
     * Replaces invalid UTF-8 bytes with replacement character
     */
    std::string sanitizeUtf8(const std::string& str) {
        std::string result;
        size_t i = 0;
        while (i < str.length()) {
            unsigned char c = str[i];

            // Check for valid UTF-8 sequences
            int charLen = 0;
            if ((c & 0x80) == 0) {
                // ASCII (0xxxxxxx)
                charLen = 1;
            } else if ((c & 0xE0) == 0xC0) {
                // 2-byte sequence (110xxxxx)
                charLen = 2;
            } else if ((c & 0xF0) == 0xE0) {
                // 3-byte sequence (1110xxxx)
                charLen = 3;
            } else if ((c & 0xF8) == 0xF0) {
                // 4-byte sequence (11110xxx)
                charLen = 4;
            } else {
                // Invalid UTF-8 start byte - replace with space
                result += ' ';
                i++;
                continue;
            }

            // Check if we have enough bytes
            if (i + charLen > str.length()) {
                result += ' ';
                i++;
                continue;
            }

            // Validate continuation bytes
            bool valid = true;
            for (int j = 1; j < charLen; j++) {
                if ((str[i + j] & 0xC0) != 0x80) {
                    valid = false;
                    break;
                }
            }

            if (valid) {
                result += str.substr(i, charLen);
                i += charLen;
            } else {
                result += ' ';
                i++;
            }
        }
        return result;
    }

    MNN::Transformer::Llm* llm_;
    std::string modelDir_;
    int nThreads_;
    bool initialized_;
    std::mutex mutex_;
};

// Global instance
static std::unique_ptr<MnnLlmContext> g_mnnContext;
static std::mutex g_contextMutex;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_acautomaton_receipt_tamer_MnnEngine_loadModel(
        JNIEnv* env,
        jobject thiz,
        jstring modelDir,
        jint nThreads) {

    std::lock_guard<std::mutex> lock(g_contextMutex);

    const char* dir = env->GetStringUTFChars(modelDir, nullptr);
    std::string modelDirStr(dir);
    env->ReleaseStringUTFChars(modelDir, dir);

    if (!g_mnnContext) {
        g_mnnContext = std::make_unique<MnnLlmContext>();
    }

    bool success = g_mnnContext->loadModel(modelDirStr, nThreads);
    return success ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jstring JNICALL
Java_com_acautomaton_receipt_tamer_MnnEngine_generate(
        JNIEnv* env,
        jobject thiz,
        jstring prompt,
        jint maxTokens,
        jfloat temperature,
        jfloat topP) {

    const char* promptStr = env->GetStringUTFChars(prompt, nullptr);
    std::string promptCpp(promptStr);
    env->ReleaseStringUTFChars(prompt, promptStr);

    std::string result;
    if (g_mnnContext && g_mnnContext->isInitialized()) {
        result = g_mnnContext->generate(promptCpp, maxTokens, temperature, topP);
    }

    return env->NewStringUTF(result.c_str());
}

JNIEXPORT void JNICALL
Java_com_acautomaton_receipt_tamer_MnnEngine_dispose(
        JNIEnv* env,
        jobject thiz) {

    std::lock_guard<std::mutex> lock(g_contextMutex);

    if (g_mnnContext) {
        g_mnnContext->dispose();
        g_mnnContext.reset();
    }
}

JNIEXPORT jboolean JNICALL
Java_com_acautomaton_receipt_tamer_MnnEngine_isInitialized(
        JNIEnv* env,
        jobject thiz) {

    return (g_mnnContext && g_mnnContext->isInitialized()) ? JNI_TRUE : JNI_FALSE;
}

/**
 * Disable OpenMP affinity to prevent crashes on some Android devices.
 * This fixes a crash in libRapidOcr.so on Xiaomi/MIUI devices where
 * the OpenMP runtime (KMP) fails to set CPU thread affinity.
 *
 * Must be called BEFORE loading any library that uses OpenMP (e.g., RapidOcr).
 */
JNIEXPORT void JNICALL
Java_com_acautomaton_receipt_tamer_MainActivity_setOmpAffinityDisabled(
        JNIEnv* env,
        jobject thiz) {

    // Disable OpenMP affinity - prevents crash on Xiaomi devices
    setenv("KMP_AFFINITY", "disabled", 1);
    setenv("OMP_PROC_BIND", "false", 1);
    LOGI("OpenMP affinity disabled (KMP_AFFINITY=disabled, OMP_PROC_BIND=false)");
}

} // extern "C"