// Standalone native Paradee v1.2 bm_fable prototype.
// Uses ONNX Runtime and eSpeak NG; no Python runtime is needed at playback.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <onnxruntime_cxx_api.h>
#include "vocab.h"
#include "paradee_engine.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <memory>
#include <mutex>
#include <regex>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

std::string ToUtf8(const std::wstring& value) {
    if (value.empty()) return {};
    int count = WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    if (count <= 0) throw std::runtime_error("UTF-8 conversion failed");
    std::string result(count, '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), result.data(), count, nullptr, nullptr);
    return result;
}

std::wstring FromUtf8(const std::string& value) {
    if (value.empty()) return {};
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), nullptr, 0);
    if (count <= 0) throw std::runtime_error("Invalid UTF-8 phonemes");
    std::wstring result(count, L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), result.data(), count);
    return result;
}

void ReplaceAll(std::wstring& value, const std::wstring& from, const std::wstring& to) {
    size_t pos = 0;
    while ((pos = value.find(from, pos)) != std::wstring::npos) {
        value.replace(pos, from.size(), to);
        pos += to.size();
    }
}

std::wstring ToMisakiBritish(std::wstring value) {
    // Mirrors upstream Paradee web/misaki.js for the British voice.
    ReplaceAll(value, L"eə", L"ɛː");
    static const std::pair<const wchar_t*, const wchar_t*> pairs[] = {
        {L"ʔˌn̩", L"ʔn"}, {L"ʔn̩", L"ʔn"}, {L"aɪ", L"I"}, {L"aʊ", L"W"},
        {L"dʒ", L"ʤ"}, {L"eɪ", L"A"}, {L"e", L"A"}, {L"tʃ", L"ʧ"},
        {L"ɔɪ", L"Y"}, {L"ʲo", L"jo"}, {L"ʲə", L"jə"}, {L"ʲ", L""},
        {L"ɚ", L"əɹ"}, {L"r", L"ɹ"}, {L"x", L"k"}, {L"ç", L"k"},
        {L"ɬ", L"l"}, {L"̃", L""},
    };
    for (const auto& [from, to] : pairs) ReplaceAll(value, from, to);
    value = std::regex_replace(value, std::wregex(L"(\\S)̩"), L"ᵊ$1");
    ReplaceAll(value, L"̩", L"");
    value = std::regex_replace(value, std::wregex(L"əl(?=[\\s;:,.!?—…\"“”()]|$)"), L"ᵊl");
    value = std::regex_replace(value, std::wregex(L"ɐ(?!n?(?:[\\s;:,.!?—…\"“”()]|$))"), L"ə");
    ReplaceAll(value, L"iə", L"ɪə");
    ReplaceAll(value, L"əʊ", L"Q");
    value = std::regex_replace(value, std::wregex(L"(^|\\s)ðɪ(?=\\s|$)"), L"$1ði");
    ReplaceAll(value, L"o", L"ɔ");
    ReplaceAll(value, L"ɾ", L"T");
    ReplaceAll(value, L"ʔ", L"t");
    return value;
}

class Espeak {
public:
    explicit Espeak(const std::wstring& assets) {
        dll_ = LoadLibraryW((assets + L"\\espeak-ng.dll").c_str());
        if (!dll_) throw std::runtime_error("Cannot load espeak-ng.dll");
        initialize_ = reinterpret_cast<Initialize>(GetProcAddress(dll_, "espeak_Initialize"));
        set_voice_ = reinterpret_cast<SetVoice>(GetProcAddress(dll_, "espeak_SetVoiceByName"));
        phonemes_ = reinterpret_cast<TextToPhonemes>(GetProcAddress(dll_, "espeak_TextToPhonemes"));
        if (!initialize_ || !set_voice_ || !phonemes_) throw std::runtime_error("Missing eSpeak NG entry point");
        auto path = ToUtf8(assets);
        if (initialize_(1, 0, path.c_str(), 0) < 0) throw std::runtime_error("eSpeak NG initialization failed");
        if (set_voice_("English (Great Britain)") != 0) throw std::runtime_error("Cannot select eSpeak British voice");
    }
    ~Espeak() { if (dll_) FreeLibrary(dll_); }

    std::wstring Phonemize(const std::wstring& text) const {
        std::string utf8 = ToUtf8(text);
        const void* ptr = utf8.c_str();
        std::string result;
        while (ptr) {
            const char* clause = phonemes_(&ptr, 1, 2);
            if (!clause) break;
            if (!result.empty()) result += ' ';
            result += clause;
        }
        if (!text.empty()) {
            wchar_t last = text.back();
            if (last == L'.' || last == L'!' || last == L'?' || last == L',' || last == L';' || last == L':')
                result += static_cast<char>(last);
        }
        return ToMisakiBritish(FromUtf8(result));
    }

private:
    using Initialize = int(__cdecl*)(int, int, const char*, int);
    using SetVoice = int(__cdecl*)(const char*);
    using TextToPhonemes = const char*(__cdecl*)(const void**, int, int);
    HMODULE dll_ = nullptr;
    Initialize initialize_ = nullptr;
    SetVoice set_voice_ = nullptr;
    TextToPhonemes phonemes_ = nullptr;
};

std::vector<int64_t> Tokens(const std::wstring& phonemes) {
    std::vector<int64_t> ids{0};
    for (wchar_t c : phonemes) {
        auto found = kParadeeVocab.find(c);
        if (found != kParadeeVocab.end()) ids.push_back(found->second);
        if (ids.size() == 511) break;
    }
    ids.push_back(0);
    return ids;
}

void WriteWav(const std::wstring& path, const float* samples, size_t count) {
    std::ofstream file(path, std::ios::binary);
    if (!file) throw std::runtime_error("Cannot create WAV file");
    uint32_t bytes = static_cast<uint32_t>(count * sizeof(int16_t));
    uint32_t riff = bytes + 36;
    uint32_t fmt_size = 16;
    uint16_t pcm = 1, channels = 1, align = 2, bits = 16;
    uint32_t rate = 24000, byte_rate = rate * align;
    file.write("RIFF", 4); file.write(reinterpret_cast<const char*>(&riff), 4);
    file.write("WAVEfmt ", 8); file.write(reinterpret_cast<const char*>(&fmt_size), 4);
    file.write(reinterpret_cast<const char*>(&pcm), 2); file.write(reinterpret_cast<const char*>(&channels), 2);
    file.write(reinterpret_cast<const char*>(&rate), 4); file.write(reinterpret_cast<const char*>(&byte_rate), 4);
    file.write(reinterpret_cast<const char*>(&align), 2); file.write(reinterpret_cast<const char*>(&bits), 2);
    file.write("data", 4); file.write(reinterpret_cast<const char*>(&bytes), 4);
    for (size_t i = 0; i < count; ++i) {
        int16_t sample = static_cast<int16_t>(std::clamp(samples[i], -1.0f, 1.0f) * 32767);
        file.write(reinterpret_cast<const char*>(&sample), 2);
    }
}

class NativeEngine {
public:
    explicit NativeEngine(const std::wstring& assets)
        : espeak_(assets), env_(ORT_LOGGING_LEVEL_WARNING, "paradee-native") {
        Ort::SessionOptions options;
        options.SetIntraOpNumThreads(1);
        options.SetInterOpNumThreads(1);
        options.DisableCpuMemArena();
        session_ = std::make_unique<Ort::Session>(env_, (assets + L"\\paradee_int8.onnx").c_str(), options);
    }

    std::vector<float> Synthesize(const std::wstring& text, float speed) {
        auto phonemes = espeak_.Phonemize(text);
        auto ids = Tokens(phonemes);
        Ort::MemoryInfo cpu = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
        std::array<int64_t, 2> ids_shape{1, static_cast<int64_t>(ids.size())};
        std::array<int64_t, 1> scalar_shape{1};
        int64_t voice = 3;
        std::array<Ort::Value, 3> inputs = {
            Ort::Value::CreateTensor<int64_t>(cpu, ids.data(), ids.size(), ids_shape.data(), ids_shape.size()),
            Ort::Value::CreateTensor<float>(cpu, &speed, 1, scalar_shape.data(), scalar_shape.size()),
            Ort::Value::CreateTensor<int64_t>(cpu, &voice, 1, scalar_shape.data(), scalar_shape.size()),
        };
        const char* input_names[] = {"input_ids", "speed", "voice"};
        const char* output_names[] = {"waveform"};
        auto outputs = session_->Run(Ort::RunOptions{nullptr}, input_names, inputs.data(), inputs.size(), output_names, 1);
        auto info = outputs[0].GetTensorTypeAndShapeInfo();
        const float* data = outputs[0].GetTensorData<float>();
        return {data, data + info.GetElementCount()};
    }

private:
    Espeak espeak_;
    Ort::Env env_;
    std::unique_ptr<Ort::Session> session_;
};

} // namespace

std::vector<float> ParadeeSynthesize(const std::wstring& text, const std::wstring& assets_dir, float speed) {
    static std::mutex mutex;
    static std::unique_ptr<NativeEngine> engine;
    static std::wstring loaded_dir;
    std::lock_guard<std::mutex> guard(mutex);
    if (!engine || loaded_dir != assets_dir) {
        engine = std::make_unique<NativeEngine>(assets_dir);
        loaded_dir = assets_dir;
    }
    return engine->Synthesize(text, speed);
}

#ifndef PARADEE_NATIVE_LIBRARY
int wmain(int argc, wchar_t** argv) {
    if (argc != 4) {
        std::wcerr << L"Usage: paradee_native.exe TEXT OUTPUT_WAV ASSETS_DIR\n";
        return 2;
    }
    try {
        auto audio = ParadeeSynthesize(argv[1], argv[3], 1.0f);
        WriteWav(argv[2], audio.data(), audio.size());
        std::wcout << L"Wrote " << argv[2] << L" (" << audio.size() << L" samples)\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Native synthesis failed: " << error.what() << '\n';
        return 1;
    }
}
#endif
