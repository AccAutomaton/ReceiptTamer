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

#define LOG_TAG "MnnJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

/**
 * MnnLlmContext - 简化的 LLM 上下文
 *
 * 目前使用启发式规则提取 JSON，后续可以集成真正的 MNN LLM 推理
 */
class MnnLlmContext {
public:
    MnnLlmContext() : initialized_(false), nThreads_(4) {}

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

        if (!initialized_) {
            LOGE("Model not initialized");
            return "";
        }

        LOGI("========== MNN LLM Generation Start ==========");
        LOGI("Prompt length: %zu chars, maxTokens: %d", prompt.length(), maxTokens);

        auto genStart = std::chrono::high_resolution_clock::now();

        // Extract JSON using heuristics
        std::string result = extractJsonFromText(prompt);

        auto genEnd = std::chrono::high_resolution_clock::now();
        auto genMs = std::chrono::duration_cast<std::chrono::milliseconds>(genEnd - genStart).count();

        LOGI("========== MNN LLM Generation Complete ==========");
        LOGI("[DIAG] Generation time: %lldms", (long long)genMs);
        LOGI("[DIAG] Result: %s", result.c_str());

        return result;
    }

    void dispose() {
        std::lock_guard<std::mutex> lock(mutex_);
        initialized_ = false;
        LOGI("MnnLlmContext disposed");
    }

    bool isInitialized() const {
        return initialized_;
    }

private:
    std::string extractJsonFromText(const std::string& prompt) {
        // Check if this is an order or invoice extraction
        bool isOrder = prompt.find("shopName") != std::string::npos ||
                       prompt.find("amount") != std::string::npos ||
                       prompt.find("orderTime") != std::string::npos;
        bool isInvoice = prompt.find("invoiceNumber") != std::string::npos ||
                         prompt.find("totalAmount") != std::string::npos ||
                         prompt.find("invoiceDate") != std::string::npos;

        // Extract OCR text from prompt (after "OCR:" marker)
        std::string ocrText = prompt;
        size_t ocrPos = prompt.find("OCR:\n");
        if (ocrPos != std::string::npos) {
            ocrText = prompt.substr(ocrPos + 5);
        }

        if (isOrder) {
            return extractOrderJson(ocrText);
        } else if (isInvoice) {
            return extractInvoiceJson(ocrText);
        }

        return R"({"error": "Unknown extraction type"})";
    }

    std::string extractOrderJson(const std::string& text) {
        std::string shopName;
        std::string amount;
        std::string orderTime;
        std::string orderNumber;

        // Look for amount patterns
        size_t amountPos = text.find("实付");
        if (amountPos == std::string::npos) amountPos = text.find("总计");
        if (amountPos == std::string::npos) amountPos = text.find("合计");
        if (amountPos == std::string::npos) amountPos = text.find("¥");
        if (amountPos == std::string::npos) amountPos = text.find("￥");

        if (amountPos != std::string::npos) {
            size_t start = text.find_first_of("0123456789", amountPos);
            if (start != std::string::npos) {
                size_t end = start;
                while (end < text.length() && (text[end] == '.' || isdigit(text[end]))) {
                    end++;
                }
                amount = text.substr(start, end - start);
            }
        }

        // Look for order number
        size_t orderPos = text.find("订单号");
        if (orderPos == std::string::npos) orderPos = text.find("订单编号");
        if (orderPos == std::string::npos) orderPos = text.find("订单");

        if (orderPos != std::string::npos) {
            size_t start = text.find_first_of("0123456789", orderPos);
            if (start != std::string::npos) {
                size_t end = start;
                while (end < text.length() && isdigit(text[end])) {
                    end++;
                }
                if (end - start >= 8) {
                    orderNumber = text.substr(start, end - start);
                }
            }
        }

        // Look for time patterns
        size_t timePos = text.find("下单时间");
        if (timePos == std::string::npos) timePos = text.find("时间");

        if (timePos != std::string::npos) {
            size_t start = text.find_first_of("0123456789", timePos);
            if (start != std::string::npos) {
                size_t end = start;
                while (end < text.length() && (isdigit(text[end]) || text[end] == '-' ||
                       text[end] == ':' || text[end] == ' ' || text[end] == '/')) {
                    end++;
                }
                orderTime = text.substr(start, end - start);
                // Trim trailing spaces and dashes
                while (!orderTime.empty() && (orderTime.back() == ' ' || orderTime.back() == '-')) {
                    orderTime.pop_back();
                }
            }
        }

        // Build JSON
        std::ostringstream json;
        json << "{\"shopName\":\"" << escapeJson(shopName) << "\","
             << "\"amount\":" << (amount.empty() ? "0.0" : amount) << ","
             << "\"orderTime\":\"" << escapeJson(orderTime) << "\","
             << "\"orderNumber\":\"" << escapeJson(orderNumber) << "\"}";

        return json.str();
    }

    std::string extractInvoiceJson(const std::string& text) {
        std::string invoiceNumber;
        std::string invoiceDate;
        std::string totalAmount;

        // Look for invoice number
        size_t numPos = text.find("发票号码");
        if (numPos == std::string::npos) numPos = text.find("号码");

        if (numPos != std::string::npos) {
            size_t start = text.find_first_of("0123456789", numPos);
            if (start != std::string::npos) {
                size_t end = start;
                while (end < text.length() && isdigit(text[end])) {
                    end++;
                }
                invoiceNumber = text.substr(start, end - start);
            }
        }

        // Look for date
        size_t datePos = text.find("开票日期");
        if (datePos == std::string::npos) datePos = text.find("日期");

        if (datePos != std::string::npos) {
            size_t start = text.find_first_of("0123456789", datePos);
            if (start != std::string::npos) {
                size_t end = start;
                // Check for Chinese date characters (年/月/日) - UTF-8 encoded
                while (end < text.length()) {
                    unsigned char c = text[end];
                    if (isdigit(c) || c == '-' || c == '/') {
                        end++;
                    } else if (end + 2 < text.length()) {
                        // Check for UTF-8 Chinese characters
                        unsigned char c1 = text[end];
                        unsigned char c2 = text[end + 1];
                        unsigned char c3 = text[end + 2];
                        bool isChineseDateChar = (c1 == 0xE5 && c2 == 0xB9 && c3 == 0xB4) ||  // 年
                                                  (c1 == 0xE6 && c2 == 0x9C && c3 == 0x88) ||  // 月
                                                  (c1 == 0xE6 && c2 == 0x97 && c3 == 0xA5);    // 日
                        if (isChineseDateChar) {
                            end += 3;
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                }
                invoiceDate = text.substr(start, end - start);
            }
        }

        // Look for total amount
        size_t amountPos = text.find("价税合计");
        if (amountPos == std::string::npos) amountPos = text.find("合计金额");
        if (amountPos == std::string::npos) amountPos = text.find("金额");
        if (amountPos == std::string::npos) amountPos = text.find("¥");

        if (amountPos != std::string::npos) {
            size_t start = text.find_first_of("0123456789", amountPos);
            if (start != std::string::npos) {
                size_t end = start;
                while (end < text.length() && (text[end] == '.' || isdigit(text[end]))) {
                    end++;
                }
                totalAmount = text.substr(start, end - start);
            }
        }

        // Build JSON
        std::ostringstream json;
        json << "{\"invoiceNumber\":\"" << escapeJson(invoiceNumber) << "\","
             << "\"invoiceDate\":\"" << escapeJson(invoiceDate) << "\","
             << "\"totalAmount\":" << (totalAmount.empty() ? "0.0" : totalAmount) << "}";

        return json.str();
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
Java_com_acautomaton_catering_1receipt_1recorder_MnnEngine_loadModel(
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
Java_com_acautomaton_catering_1receipt_1recorder_MnnEngine_generate(
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
Java_com_acautomaton_catering_1receipt_1recorder_MnnEngine_dispose(
        JNIEnv* env,
        jobject thiz) {

    std::lock_guard<std::mutex> lock(g_contextMutex);

    if (g_mnnContext) {
        g_mnnContext->dispose();
        g_mnnContext.reset();
    }
}

JNIEXPORT jboolean JNICALL
Java_com_acautomaton_catering_1receipt_1recorder_MnnEngine_isInitialized(
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
Java_com_acautomaton_catering_1receipt_1recorder_MainActivity_setOmpAffinityDisabled(
        JNIEnv* env,
        jobject thiz) {

    // Disable OpenMP affinity - prevents crash on Xiaomi devices
    setenv("KMP_AFFINITY", "disabled", 1);
    setenv("OMP_PROC_BIND", "false", 1);
    LOGI("OpenMP affinity disabled (KMP_AFFINITY=disabled, OMP_PROC_BIND=false)");
}

} // extern "C"