// Standalone native Paradee v1.2 four-voice engine.
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
#include <cwctype>
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

std::wstring ToMisaki(std::wstring value, bool british) {
    // Mirrors upstream Paradee web/misaki.js for both English frontends.
    if (british) ReplaceAll(value, L"eə", L"ɛː");
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
    value = std::regex_replace(value,
        std::wregex(british ? L"ɐ(?!n?(?:[\\s;:,.!?—…\"“”()]|$))"
                            : L"ɐ(?![\\s;:,.!?—…\"“”()]|$)"), L"ə");
    if (british) {
        ReplaceAll(value, L"iə", L"ɪə");
        ReplaceAll(value, L"əʊ", L"Q");
        value = std::regex_replace(value, std::wregex(L"(^|\\s)ðɪ(?=\\s|$)"), L"$1ði");
    } else {
        ReplaceAll(value, L"oʊ", L"O");
        ReplaceAll(value, L"ɜːɹ", L"ɜɹ");
        ReplaceAll(value, L"ɜː", L"ɜɹ");
        ReplaceAll(value, L"ɪə", L"iə");
        ReplaceAll(value, L"ː", L"");
    }
    ReplaceAll(value, L"o", L"ɔ");
    ReplaceAll(value, L"ɾ", L"T");
    ReplaceAll(value, L"ʔ", L"t");
    return value;
}

std::wstring NumberWords(int value) {
    static const wchar_t* small[] = {
        L"zero", L"one", L"two", L"three", L"four", L"five", L"six", L"seven",
        L"eight", L"nine", L"ten", L"eleven", L"twelve", L"thirteen", L"fourteen",
        L"fifteen", L"sixteen", L"seventeen", L"eighteen", L"nineteen"
    };
    static const wchar_t* tens[] = {
        L"", L"", L"twenty", L"thirty", L"forty", L"fifty"
    };
    if (value < 20) return small[value];
    std::wstring result = tens[value / 10];
    if (value % 10) result += std::wstring(L" ") + small[value % 10];
    return result;
}

std::wstring NormalizeTimes(const std::wstring& text) {
    std::wstring result;
    for (size_t i = 0; i < text.size();) {
        if (i && std::iswalnum(text[i - 1])) { result += text[i++]; continue; }
        size_t hour_end = i;
        while (hour_end < text.size() && hour_end - i < 2 &&
               text[hour_end] >= L'0' && text[hour_end] <= L'9') ++hour_end;
        if (hour_end == i || hour_end >= text.size() || text[hour_end] != L':' ||
            hour_end + 2 >= text.size() ||
            text[hour_end + 1] < L'0' || text[hour_end + 1] > L'9' ||
            text[hour_end + 2] < L'0' || text[hour_end + 2] > L'9') {
            result += text[i++];
            continue;
        }
        int hour = 0;
        for (size_t j = i; j < hour_end; ++j) hour = hour * 10 + (text[j] - L'0');
        int minute = (text[hour_end + 1] - L'0') * 10 + (text[hour_end + 2] - L'0');
        if (hour > 23 || minute > 59) { result += text[i++]; continue; }
        size_t end = hour_end + 3;
        size_t suffix = end;
        while (suffix < text.size() && std::iswspace(text[suffix])) ++suffix;
        const bool meridiem = suffix + 1 < text.size() &&
            (text[suffix] == L'A' || text[suffix] == L'a' ||
             text[suffix] == L'P' || text[suffix] == L'p') &&
            (text[suffix + 1] == L'M' || text[suffix + 1] == L'm') &&
            (suffix + 2 == text.size() || !std::iswalnum(text[suffix + 2])) &&
            hour >= 1 && hour <= 12;
        if (end < text.size() && std::iswalnum(text[end]) && !meridiem) {
            result += text[i++];
            continue;
        }
        result += NumberWords(hour);
        if (minute == 0) {
            if (!meridiem) result += L" o'clock";
        } else {
            result += minute < 10 ? L" oh " : L" ";
            result += NumberWords(minute);
        }
        if (meridiem) {
            result += L" ";
            result += (text[suffix] == L'A' || text[suffix] == L'a') ? L"AM" : L"PM";
            end = suffix + 2;
        }
        i = end;
    }
    return result;
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

    std::wstring Phonemize(const std::wstring& text, int voice_index) const {
        const bool italian = voice_index == 4;
        const bool british = voice_index == 1 || voice_index == 3;
        const char* voice_name = italian ? "Italian" :
            (british ? "English (Great Britain)" : "English (America)");
        if (set_voice_(voice_name) != 0) throw std::runtime_error("Cannot select eSpeak voice");
        // Italian eSpeak already verbalizes numbers in Italian. English time
        // expansion must not leak into this language's pronunciation path.
        const std::wstring normalized = italian ? text : NormalizeTimes(text);
        std::wstring result;
        size_t start = 0;
        for (size_t i = 0; i <= normalized.size(); ++i) {
            const bool inside_number = i > 0 && i + 1 < normalized.size() &&
                std::iswdigit(normalized[i - 1]) && std::iswdigit(normalized[i + 1]);
            const bool punctuation = i < normalized.size() &&
                (((normalized[i] == L',' || normalized[i] == L'.') && !inside_number) ||
                 normalized[i] == L';' || normalized[i] == L':' || normalized[i] == L'!' ||
                 normalized[i] == L'?' || normalized[i] == L'…');
            if (!punctuation && i != normalized.size()) continue;
            const auto clause_text = normalized.substr(start, i - start);
            if (!clause_text.empty()) {
                std::string utf8 = ToUtf8(clause_text);
                const void* ptr = utf8.c_str();
                std::string clause_result;
                while (ptr) {
                    const char* clause = phonemes_(&ptr, 1, 2);
                    if (!clause) break;
                    if (!clause_result.empty()) clause_result += ' ';
                    clause_result += clause;
                }
                if (!clause_result.empty()) {
                    if (!result.empty() && !std::iswspace(result.back())) result += L' ';
                    result += FromUtf8(clause_result);
                }
            }
            if (punctuation) {
                result += normalized[i];
                start = i + 1;
            }
        }
        if (italian) {
            ReplaceAll(result, L"̪", L""); // Kokoro's Italian vocabulary uses t/d, not dental-marked IPA.
            return result;
        }
        return ToMisaki(result, british);
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
    }
    if (ids.size() > 511) throw std::runtime_error("Phoneme chunk exceeds model limit");
    ids.push_back(0);
    return ids;
}

std::vector<std::wstring> PhonemeChunks(std::wstring phonemes) {
    std::vector<std::wstring> chunks;
    while (phonemes.size() > 510) {
        size_t cut = phonemes.rfind(L' ', 509);
        if (cut == std::wstring::npos || cut == 0) cut = 510;
        chunks.push_back(phonemes.substr(0, cut));
        phonemes.erase(0, cut);
        while (!phonemes.empty() && std::iswspace(phonemes.front())) phonemes.erase(0, 1);
    }
    if (!phonemes.empty()) chunks.push_back(std::move(phonemes));
    return chunks;
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
        : assets_(assets), espeak_(assets), env_(ORT_LOGGING_LEVEL_WARNING, "paradee-native") {}

    std::vector<float> Synthesize(const std::wstring& text, float speed, int voice_index) {
        if (voice_index < 0 || voice_index > 4) throw std::invalid_argument("Invalid Paradee voice index");
        const bool italian = voice_index == 4;
        if (italian && !is_italian_pack_) throw std::invalid_argument("Italian voice is not available in this package");
        Ort::Session* session = GetSession(italian);
        std::vector<float> audio;
        for (const auto& sentence : ParadeeSplitSentences(text)) {
            for (const auto& chunk : PhonemeChunks(espeak_.Phonemize(sentence, voice_index))) {
                auto ids = Tokens(chunk);
                Ort::MemoryInfo cpu = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
                std::array<int64_t, 2> ids_shape{1, static_cast<int64_t>(ids.size())};
                std::array<int64_t, 1> scalar_shape{1};
                if (italian) {
                    std::array<Ort::Value, 2> inputs = {
                        Ort::Value::CreateTensor<int64_t>(cpu, ids.data(), ids.size(), ids_shape.data(), ids_shape.size()),
                        Ort::Value::CreateTensor<float>(cpu, &speed, 1, scalar_shape.data(), scalar_shape.size()),
                    };
                    const char* input_names[] = {"input_ids", "speed"};
                    const char* output_names[] = {"waveform"};
                    auto outputs = session->Run(Ort::RunOptions{nullptr}, input_names, inputs.data(), inputs.size(), output_names, 1);
                    auto info = outputs[0].GetTensorTypeAndShapeInfo();
                    const float* data = outputs[0].GetTensorData<float>();
                    audio.insert(audio.end(), data, data + info.GetElementCount());
                } else {
                    int64_t voice = voice_index;
                    std::array<Ort::Value, 3> inputs = {
                    Ort::Value::CreateTensor<int64_t>(cpu, ids.data(), ids.size(), ids_shape.data(), ids_shape.size()),
                    Ort::Value::CreateTensor<float>(cpu, &speed, 1, scalar_shape.data(), scalar_shape.size()),
                    Ort::Value::CreateTensor<int64_t>(cpu, &voice, 1, scalar_shape.data(), scalar_shape.size()),
                    };
                    const char* input_names[] = {"input_ids", "speed", "voice"};
                    const char* output_names[] = {"waveform"};
                    auto outputs = session->Run(Ort::RunOptions{nullptr}, input_names, inputs.data(), inputs.size(), output_names, 1);
                    auto info = outputs[0].GetTensorTypeAndShapeInfo();
                    const float* data = outputs[0].GetTensorData<float>();
                    audio.insert(audio.end(), data, data + info.GetElementCount());
                }
            }
        }
        return audio;
    }

private:
    Ort::Session* GetSession(bool italian) {
        auto& session = italian ? italian_session_ : english_session_;
        if (!session) {
            const std::wstring model = assets_ + (italian ? L"\\if_sara-model_int8.onnx" : L"\\paradee_int8.onnx");
            Ort::SessionOptions options;
            options.SetIntraOpNumThreads(1);
            options.SetInterOpNumThreads(1);
            options.DisableCpuMemArena();
            session = std::make_unique<Ort::Session>(env_, model.c_str(), options);
        }
        return session.get();
    }

    static constexpr bool is_italian_pack_ =
#ifdef PARADEE_ITALIAN_PACK
        true;
#else
        false;
#endif
    std::wstring assets_;
    Espeak espeak_;
    Ort::Env env_;
    std::unique_ptr<Ort::Session> english_session_;
    std::unique_ptr<Ort::Session> italian_session_;
};

} // namespace

std::vector<std::wstring> ParadeeSplitSentences(const std::wstring& text) {
    std::vector<std::wstring> sentences;
    size_t start = 0;
    auto append = [&](size_t end) {
        while (start < end && std::iswspace(text[start])) ++start;
        while (end > start && std::iswspace(text[end - 1])) --end;
        if (end > start) sentences.push_back(text.substr(start, end - start));
    };
    for (size_t i = 0; i < text.size(); ++i) {
        if (text[i] == L'\n' || text[i] == L'\r') {
            append(i);
            start = i + 1;
        } else if ((text[i] == L'.' || text[i] == L'!' || text[i] == L'?' || text[i] == L'…') &&
                   (i + 1 == text.size() || std::iswspace(text[i + 1]))) {
            append(i + 1);
            start = i + 1;
        }
    }
    append(text.size());
    return sentences;
}

std::vector<float> ParadeeSynthesize(const std::wstring& text, const std::wstring& assets_dir, float speed, int voice_index) {
    static std::mutex mutex;
    static std::unique_ptr<NativeEngine> engine;
    static std::wstring loaded_dir;
    std::lock_guard<std::mutex> guard(mutex);
    if (!engine || loaded_dir != assets_dir) {
        engine = std::make_unique<NativeEngine>(assets_dir);
        loaded_dir = assets_dir;
    }
    return engine->Synthesize(text, speed, voice_index);
}

#ifndef PARADEE_NATIVE_LIBRARY
int wmain(int argc, wchar_t** argv) {
    if (argc != 4 && argc != 5) {
        std::wcerr << L"Usage: paradee_native.exe TEXT OUTPUT_WAV ASSETS_DIR [VOICE_INDEX]\n";
        return 2;
    }
    try {
        int voice_index = argc == 5 ? std::stoi(argv[4]) : 3;
        auto audio = ParadeeSynthesize(argv[1], argv[3], 1.0f, voice_index);
        WriteWav(argv[2], audio.data(), audio.size());
        std::wcout << L"Wrote " << argv[2] << L" (" << audio.size() << L" samples)\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Native synthesis failed: " << error.what() << '\n';
        return 1;
    }
}
#endif
