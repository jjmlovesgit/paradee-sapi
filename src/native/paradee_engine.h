#pragma once

#include <string>
#include <vector>

// Native Paradee v1.2 bm_fable inference. Thread-safe; keeps one warm session
// per process and never sends input text to a service.
std::vector<float> ParadeeSynthesize(
    const std::wstring& text,
    const std::wstring& assets_dir,
    float speed);
