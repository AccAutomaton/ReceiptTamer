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
#include <queue>
#include <condition_variable>
#include <thread>
#include <atomic>
#include "mnn_llm.hpp"

// ========== 异步日志桥接系统 ==========
// C++层日志先进入缓冲队列，后台线程批量发送到Kotlin层
// 通过批量发送和异步处理避免JNI调用开销影响性能

#define LOG_TAG "MnnJNI"

// 日志级别常量
#define LOG_LEVEL_DEBUG "D"
#define LOG_LEVEL_INFO  "I"
#define LOG_LEVEL_ERROR "E"

// 日志批量发送配置
static const size_t LOG_BATCH_SIZE = 10;       // 批量发送阈值
static const int LOG_FLUSH_INTERVAL_MS = 100;  // 最大刷新间隔

// 日志条目结构
struct LogEntry {
    std::string level;
    std::string module;
    std::string message;
};

// 线程安全的日志缓冲队列
class LogBuffer {
public:
    void push(const std::string& level, const std::string& module, const std::string& message) {
        std::lock_guard<std::mutex> lock(mutex_);
        queue_.push({level, module, message});
        // 达到批量大小时立即通知发送线程
        if (queue_.size() >= LOG_BATCH_SIZE) {
            cond_.notify_one();
        }
    }

    // 等待并获取批量日志（带超时）
    std::vector<LogEntry> popBatch() {
        std::unique_lock<std::mutex> lock(mutex_);
        // 等待条件：有日志或超时
        cond_.wait_for(lock, std::chrono::milliseconds(LOG_FLUSH_INTERVAL_MS),
                       [this] { return !queue_.empty(); });

        std::vector<LogEntry> batch;
        while (!queue_.empty() && batch.size() < LOG_BATCH_SIZE * 2) {
            batch.push_back(queue_.front());
            queue_.pop();
        }
        return batch;
    }

    size_t size() {
        std::lock_guard<std::mutex> lock(mutex_);
        return queue_.size();
    }

private:
    std::queue<LogEntry> queue_;
    std::mutex mutex_;
    std::condition_variable cond_;
};

// 全局日志缓冲
static LogBuffer g_logBuffer;
static std::atomic<bool> g_logThreadRunning(false);
static std::thread g_logThread;
static JavaVM* g_javaVm = nullptr;
static jclass g_logReceiverClass = nullptr;  // 全局引用：LogReceiver类

// 后台日志发送线程
void logSenderThread() {
    while (g_logThreadRunning) {
        auto batch = g_logBuffer.popBatch();
        if (batch.empty()) continue;

        // 获取JNI环境
        JNIEnv* env = nullptr;
        bool needDetach = false;

        if (g_javaVm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_EDETACHED) {
            g_javaVm->AttachCurrentThread(&env, nullptr);
            needDetach = true;
        }

        if (env && g_logReceiverClass) {
            // 获取静态方法ID
            jmethodID methodId = env->GetStaticMethodID(
                g_logReceiverClass,
                "receiveLog",
                "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V"
            );

            if (methodId) {
                // 发送每条日志
                for (const auto& entry : batch) {
                    jstring jLevel = env->NewStringUTF(entry.level.c_str());
                    jstring jModule = env->NewStringUTF(entry.module.c_str());
                    jstring jMessage = env->NewStringUTF(entry.message.c_str());

                    env->CallStaticVoidMethod(
                        g_logReceiverClass,
                        methodId,
                        jLevel, jModule, jMessage
                    );

                    env->DeleteLocalRef(jLevel);
                    env->DeleteLocalRef(jModule);
                    env->DeleteLocalRef(jMessage);
                }
            }
        }

        if (needDetach) {
            g_javaVm->DetachCurrentThread();
        }
    }
}

// 初始化日志桥接系统
void initLogBridge(JNIEnv* env) {
    if (g_logThreadRunning) return;

    // 保存JavaVM引用
    env->GetJavaVM(&g_javaVm);

    // 获取LogReceiver类并创建全局引用
    jclass localClass = env->FindClass("com/acautomaton/receipt/tamer/LogReceiver");
    if (localClass) {
        g_logReceiverClass = reinterpret_cast<jclass>(env->NewGlobalRef(localClass));
        env->DeleteLocalRef(localClass);
    }

    // 启动后台发送线程
    g_logThreadRunning = true;
    g_logThread = std::thread(logSenderThread);
}

// 关闭日志桥接系统
void shutdownLogBridge() {
    g_logThreadRunning = false;
    if (g_logThread.joinable()) {
        g_logThread.join();
    }
}

// 新的日志宏：将日志放入缓冲队列
#define LOGI(...) do { \
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__); \
    char buf[512]; \
    snprintf(buf, sizeof(buf), __VA_ARGS__); \
    g_logBuffer.push(LOG_LEVEL_INFO, "LLM", std::string(buf)); \
} while(0)

#define LOGE(...) do { \
    __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__); \
    char buf[512]; \
    snprintf(buf, sizeof(buf), __VA_ARGS__); \
    g_logBuffer.push(LOG_LEVEL_ERROR, "LLM", std::string(buf)); \
} while(0)

#define LOGD(...) do { \
    __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__); \
    char buf[512]; \
    snprintf(buf, sizeof(buf), __VA_ARGS__); \
    g_logBuffer.push(LOG_LEVEL_DEBUG, "LLM", std::string(buf)); \
} while(0)

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
            LOGE("模型已加载");
            return false;
        }

        auto totalStart = std::chrono::high_resolution_clock::now();

        LOGI("========== MNN LLM 模型加载中 ==========");
        LOGI("模型目录: %s", modelDir.c_str());
        LOGI("线程数: %d", nThreads);

        // Check if model directory exists
        std::string configPath = modelDir + "/llm_config.json";
        std::ifstream configFile(configPath);
        if (!configFile.good()) {
            LOGE("配置文件未找到: %s", configPath.c_str());
            return false;
        }
        configFile.close();

        // Check model files
        std::string modelPath = modelDir + "/llm.mnn";
        std::string weightPath = modelDir + "/llm.mnn.weight";

        std::ifstream modelFile(modelPath);
        if (!modelFile.good()) {
            LOGE("模型文件未找到: %s", modelPath.c_str());
            return false;
        }
        modelFile.close();

        std::ifstream weightFile(weightPath);
        if (!weightFile.good()) {
            LOGE("权重文件未找到: %s", weightPath.c_str());
            return false;
        }
        weightFile.close();

        // Create LLM instance
        LOGI("正在创建 MNN LLM 实例...");
        llm_ = MNN::Transformer::Llm::createLLM(configPath);
        if (!llm_) {
            LOGE("创建 MNN LLM 实例失败");
            return false;
        }

        // Load model weights
        LOGI("正在加载模型权重...");
        if (!llm_->load()) {
            LOGE("加载模型权重失败");
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

        LOGI("========== MNN LLM 模型已加载 ==========");
        LOGI("[DIAG] 总加载时间: %lldms", (long long)totalMs);

        return true;
    }

    std::string generate(const std::string& prompt, int maxTokens, float temperature, float topP) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (!initialized_ || !llm_) {
            LOGE("模型未初始化");
            return "";
        }

        LOGI("========== MNN LLM 推理开始 ==========");
        LOGI("提示词长度: %zu 字符, 最大 token 数: %d", prompt.length(), maxTokens);

        auto genStart = std::chrono::high_resolution_clock::now();

        // Format prompt in Qwen chat format
        std::string formattedPrompt = "<|im_start|>user\n" + prompt + "<|im_end|>\n<|im_start|>assistant\n";
        LOGI("[DIAG] 格式化后提示词长度: %zu", formattedPrompt.length());

        // Use string stream to capture output
        std::stringstream ss;

        // Call MNN LLM for inference
        std::string retVal = llm_->response(formattedPrompt, &ss, nullptr, maxTokens);

        auto genEnd = std::chrono::high_resolution_clock::now();
        auto genMs = std::chrono::duration_cast<std::chrono::milliseconds>(genEnd - genStart).count();

        LOGI("========== MNN LLM 推理完成 ==========");
        LOGI("[DIAG] 推理时间: %lldms", (long long)genMs);

        // Get the response from stream (this has the actual content)
        std::string rawResponse = ss.str();
        LOGI("[DIAG] 响应长度: %zu", rawResponse.length());
        LOGI("[DIAG] 响应预览: %s", rawResponse.substr(0, 200).c_str());

        // Reset LLM context to clear KV cache
        llm_->reset();

        // Extract JSON from LLM response
        std::string jsonResult = extractJsonFromResponse(rawResponse);
        LOGI("[DIAG] 提取的 JSON 长度: %zu", jsonResult.length());

        return jsonResult;
    }

    void dispose() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (llm_) {
            LOGI("正在销毁 MNN LLM 实例...");
            MNN::Transformer::Llm::destroy(llm_);
            llm_ = nullptr;
        }
        initialized_ = false;
        LOGI("MnnLlmContext 已释放");
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
            LOGE("LLM 响应为空");
            return R"({"error": "LLM 响应为空"})";
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
        LOGE("无法从 LLM 响应中提取有效 JSON");
        return R"({"error": "无法从 LLM 响应中提取 JSON"})";
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

    const char* dir = env->GetStringUTFChars(modelDir, nullptr);
    std::string modelDirStr(dir);
    env->ReleaseStringUTFChars(modelDir, dir);

    LOGI("loadModel JNI 调用: modelDir=%s, nThreads=%d", modelDirStr.c_str(), nThreads);

    std::lock_guard<std::mutex> lock(g_contextMutex);

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

    LOGI("generate JNI 调用: maxTokens=%d", maxTokens);

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

    LOGI("dispose JNI 调用");

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
    LOGI("OpenMP affinity 已禁用 (KMP_AFFINITY=disabled, OMP_PROC_BIND=false)");
}

/**
 * Initialize C++ log bridge system.
 * Starts background thread that forwards C++ logs to Kotlin LogReceiver.
 */
JNIEXPORT void JNICALL
Java_com_acautomaton_receipt_tamer_MainActivity_initCppLogBridge(
        JNIEnv* env,
        jobject thiz) {

    initLogBridge(env);
    LOGI("C++ 日志桥接已初始化");
}

/**
 * Shutdown C++ log bridge system.
 * Stops background thread and flushes remaining logs.
 */
JNIEXPORT void JNICALL
Java_com_acautomaton_receipt_tamer_MainActivity_shutdownCppLogBridge(
        JNIEnv* env,
        jobject thiz) {

    shutdownLogBridge();
}

} // extern "C"