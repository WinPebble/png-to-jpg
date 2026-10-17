#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <wincodec.h>
#include <shellapi.h>
#include <shlwapi.h>
#include <stdexcept>
#include <cwctype>
#include <cmath>
#include <wrl/client.h>

#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <iomanip>
#include <limits>
#include <sstream>
#include <string>
#include <vector>

using Microsoft::WRL::ComPtr;
namespace fs = std::filesystem;

namespace {

struct ConvertResult {
    bool ok = false;
    fs::path input;
    fs::path output;
    std::wstring error;
};

std::wstring TrimSystemMessage(std::wstring text) {
    while (!text.empty() &&
           (text.back() == L'\r' || text.back() == L'\n' ||
            text.back() == L' ' || text.back() == L'\t')) {
        text.pop_back();
    }
    return text;
}

std::wstring HResultMessage(HRESULT hr) {
    wchar_t* buffer = nullptr;
    const DWORD flags =
        FORMAT_MESSAGE_ALLOCATE_BUFFER |
        FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS;

    const DWORD count = FormatMessageW(
        flags,
        nullptr,
        static_cast<DWORD>(hr),
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        reinterpret_cast<wchar_t*>(&buffer),
        0,
        nullptr);

    std::wstring result;
    if (count && buffer) {
        result.assign(buffer, count);
        LocalFree(buffer);
        return TrimSystemMessage(result);
    }

    std::wstringstream ss;
    ss << L"HRESULT 0x"
       << std::uppercase << std::hex
       << static_cast<unsigned long>(hr);
    return ss.str();
}

bool HasPngExtension(const fs::path& path) {
    std::wstring ext = path.extension().wstring();
    std::transform(ext.begin(), ext.end(), ext.begin(), [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
    return ext == L".png";
}


// Extended paths work without changing system-wide long-path policy.
fs::path NativePath(const fs::path& path) {
    auto text = fs::absolute(path).lexically_normal().wstring();
    if (text.rfind(LR"(\\?\)", 0) == 0) return text;
    if (text.rfind(LR"(\\)", 0) == 0) return std::wstring(LR"(\\?\UNC\)") + text.substr(2);
    return std::wstring(LR"(\\?\)") + text;
}

struct TempFile {
    fs::path path;
    bool owned = false;
    ~TempFile() { if (owned) DeleteFileW(path.c_str()); }
};

HRESULT EncodeJpegAtomic(
    IWICImagingFactory* factory, const fs::path& input,
    UINT width, UINT height, double dpiX, double dpiY,
    IWICBitmapSource* pixels, fs::path& actualOutput)
{
    GUID id{};
    HRESULT hr = CoCreateGuid(&id);
    if (FAILED(hr)) return hr;
    wchar_t guid[40]{};
    StringFromGUID2(id, guid, 40);
    // Guard precedes all COM objects: handles close before cleanup on any return/throw.
    TempFile temp{input.parent_path() / (std::wstring(L".winpebble.") + guid + L".tmp")};
    {
        ComPtr<IStream> stream;
        hr = SHCreateStreamOnFileEx(temp.path.c_str(),
            STGM_WRITE | STGM_SHARE_EXCLUSIVE | STGM_FAILIFTHERE,
            FILE_ATTRIBUTE_NORMAL, TRUE, nullptr, &stream);
        if (FAILED(hr)) return hr;
        temp.owned = true;
        ComPtr<IWICBitmapEncoder> encoder;
        hr = factory->CreateEncoder(GUID_ContainerFormatJpeg, nullptr, &encoder);
        if (FAILED(hr)) return hr;
        hr = encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache);
        if (FAILED(hr)) return hr;
        ComPtr<IWICBitmapFrameEncode> frame;
        ComPtr<IPropertyBag2> options;
        hr = encoder->CreateNewFrame(&frame, &options);
        if (FAILED(hr)) return hr;
        if (!options) return E_NOINTERFACE;
        PROPBAG2 option{};
        option.pstrName = const_cast<LPOLESTR>(L"ImageQuality");
        VARIANT value{};
        value.vt = VT_R4;
        value.fltVal = 1.0f;
        hr = options->Write(1, &option, &value);
        if (FAILED(hr)) return hr;
        VARIANT accepted{};
        HRESULT propertyHr = E_FAIL;
        hr = options->Read(1, &option, nullptr, &accepted, &propertyHr);
        const bool qualityAccepted = SUCCEEDED(hr) && SUCCEEDED(propertyHr) &&
            accepted.vt == VT_R4 && accepted.fltVal == 1.0f;
        VariantClear(&accepted);
        if (!qualityAccepted) return E_FAIL;
        hr = frame->Initialize(options.Get());
        if (FAILED(hr)) return hr;
        hr = frame->SetSize(width, height);
        if (FAILED(hr)) return hr;
        hr = frame->SetResolution(dpiX, dpiY);
        if (FAILED(hr)) return hr;
        WICPixelFormatGUID format = GUID_WICPixelFormat24bppBGR;
        hr = frame->SetPixelFormat(&format);
        if (FAILED(hr)) return hr;
        if (format != GUID_WICPixelFormat24bppBGR) return WINCODEC_ERR_UNSUPPORTEDPIXELFORMAT;
        // Bound our working buffers; WIC itself may retain decoder/encoder caches.
        const UINT rows = (std::min)(height, (std::max)(1u, 1024u * 1024u / (width * 4u)));
        const UINT srcStride = width * 4u, dstStride = width * 3u;
        std::vector<BYTE> bgra(static_cast<size_t>(srcStride) * rows);
        std::vector<BYTE> bgr(static_cast<size_t>(dstStride) * rows);
        for (UINT y = 0; y < height; y += rows) {
            const UINT count = (std::min)(rows, height - y);
            WICRect rect{0, static_cast<INT>(y), static_cast<INT>(width), static_cast<INT>(count)};
            hr = pixels->CopyPixels(&rect, srcStride, srcStride * count, bgra.data());
            if (FAILED(hr)) return hr;
            for (size_t i = 0; i < static_cast<size_t>(width) * count; ++i) {
                const unsigned alpha = bgra[i * 4 + 3];
                for (size_t c = 0; c < 3; ++c)
                    bgr[i * 3 + c] = static_cast<BYTE>((bgra[i * 4 + c] * alpha +
                        255u * (255u - alpha) + 127u) / 255u);
            }
            hr = frame->WritePixels(count, dstStride, dstStride * count, bgr.data());
            if (FAILED(hr)) return hr;
        }
        hr = frame->Commit();
        if (FAILED(hr)) return hr;
        hr = encoder->Commit();
        if (FAILED(hr)) return hr;
        hr = stream->Commit(STGC_DEFAULT);
        if (FAILED(hr)) return hr;
    }
    // Always derive numbering from the original source, including races after (2).
    for (unsigned n = 1; n < 100000; ++n) {
        const auto suffix = n == 1 ? L"" : L" (" + std::to_wstring(n) + L")";
        auto output = input.parent_path() / (input.stem().wstring() + suffix + L".jpg");
        if (MoveFileExW(temp.path.c_str(), output.c_str(), MOVEFILE_WRITE_THROUGH)) {
            temp.owned = false;
            actualOutput = output;
            return S_OK;
        }
        const DWORD error = GetLastError();
        if (error != ERROR_FILE_EXISTS && error != ERROR_ALREADY_EXISTS)
            return HRESULT_FROM_WIN32(error);
    }
    return HRESULT_FROM_WIN32(ERROR_TOO_MANY_NAMES);
}


struct InputFile {
    HANDLE handle = INVALID_HANDLE_VALUE;
    ~InputFile() { if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle); }
};

// WIC may recover truncated PNG files. Reject incomplete chunks and CRC damage
// before creating any output, keeping a read lock throughout conversion.
bool ValidatePng(HANDLE handle) {
    auto read = [handle](BYTE* bytes, DWORD size) {
        DWORD got = 0;
        return ReadFile(handle, bytes, size, &got, nullptr) && got == size;
    };
    auto number = [](const BYTE* b) {
        return (static_cast<UINT>(b[0]) << 24) | (static_cast<UINT>(b[1]) << 16) |
            (static_cast<UINT>(b[2]) << 8) | b[3];
    };
    BYTE signature[8]{};
    const BYTE expected[]{137,80,78,71,13,10,26,10};
    if (!read(signature, 8) || memcmp(signature, expected, 8)) return false;
    bool first = true, dataSeen = false;
    std::vector<BYTE> buffer(65536);
    for (;;) {
        BYTE header[8]{};
        if (!read(header, 8)) return false;
        const UINT length = number(header);
        if (length > 0x7fffffff) return false;
        if (first && (memcmp(header + 4, "IHDR", 4) || length != 13)) return false;
        if (!first && !memcmp(header + 4, "IHDR", 4)) return false;
        first = false;
        const bool end = !memcmp(header + 4, "IEND", 4);
        if (end && (length != 0 || !dataSeen)) return false;
        if (!memcmp(header + 4, "IDAT", 4)) dataSeen = true;
        UINT crc = 0xffffffff;
        auto update = [&crc](const BYTE* bytes, UINT count) {
            for (UINT i = 0; i < count; ++i) {
                crc ^= bytes[i];
                for (unsigned bit = 0; bit < 8; ++bit)
                    crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
            }
        };
        update(header + 4, 4);
        for (UINT left = length; left;) {
            const UINT count = (std::min)(left, static_cast<UINT>(buffer.size()));
            if (!read(buffer.data(), count)) return false;
            update(buffer.data(), count);
            left -= count;
        }
        BYTE stored[4]{};
        if (!read(stored, 4) || number(stored) != (crc ^ 0xffffffff)) return false;
        if (end) return true;
    }
}

ConvertResult ConvertOne(
    IWICImagingFactory* factory,
    const fs::path& originalInput)
{
    ConvertResult result;
    result.input = originalInput;

    try {
        const fs::path input = NativePath(originalInput);
        if (!HasPngExtension(input)) {
            result.error = L"Input is not a .png file.";
            return result;
        }

        if (!fs::exists(input) || !fs::is_regular_file(input)) {
            result.error = L"Input file does not exist.";
            return result;
        }

        InputFile source;
        source.handle = CreateFileW(input.c_str(), GENERIC_READ, FILE_SHARE_READ,
            nullptr, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
        if (source.handle == INVALID_HANDLE_VALUE) {
            result.error = L"Could not read the PNG: " + HResultMessage(HRESULT_FROM_WIN32(GetLastError()));
            return result;
        }
        if (!ValidatePng(source.handle)) {
            result.error = L"The PNG is incomplete or has invalid chunk checksums.";
            return result;
        }
        ComPtr<IWICBitmapDecoder> decoder;
        HRESULT hr = factory->CreateDecoderFromFilename(
            input.c_str(),
            nullptr,
            GENERIC_READ,
            WICDecodeMetadataCacheOnDemand,
            &decoder);

        if (FAILED(hr)) {
            result.error = L"Could not open the PNG: " + HResultMessage(hr);
            return result;
        }

        GUID containerFormat{};
        hr = decoder->GetContainerFormat(&containerFormat);
        if (FAILED(hr) || containerFormat != GUID_ContainerFormatPng) {
            result.error = L"The file is not a valid PNG image.";
            return result;
        }

        ComPtr<IWICBitmapFrameDecode> frame;
        hr = decoder->GetFrame(0, &frame);
        if (FAILED(hr)) {
            result.error = L"Could not decode the PNG: " + HResultMessage(hr);
            return result;
        }

        UINT width = 0;
        UINT height = 0;
        hr = frame->GetSize(&width, &height);
        if (FAILED(hr) || width == 0 || height == 0 || width > 65535 || height > 65535) {
            result.error = L"Could not read image dimensions.";
            return result;
        }

        double dpiX = 96.0;
        double dpiY = 96.0;
        if (FAILED(frame->GetResolution(&dpiX, &dpiY)) || !std::isfinite(dpiX) || !std::isfinite(dpiY) || dpiX <= 0 || dpiY <= 0) {
            dpiX = 96.0;
            dpiY = 96.0;
        }

        ComPtr<IWICFormatConverter> converter;
        hr = factory->CreateFormatConverter(&converter);
        if (FAILED(hr)) {
            result.error = L"Could not initialize image conversion: " + HResultMessage(hr);
            return result;
        }

        hr = converter->Initialize(
            frame.Get(),
            GUID_WICPixelFormat32bppBGRA,
            WICBitmapDitherTypeNone,
            nullptr,
            0.0,
            WICBitmapPaletteTypeCustom);

        if (FAILED(hr)) {
            result.error = L"Could not convert PNG pixels: " + HResultMessage(hr);
            return result;
        }

        fs::path actualOutput;
        hr = EncodeJpegAtomic(factory, input, width, height, dpiX, dpiY, converter.Get(), actualOutput);

        if (FAILED(hr)) {
            result.error = L"Could not save the JPG: " + HResultMessage(hr);
            return result;
        }

        result.ok = true;
        result.output = actualOutput;
        return result;
    }
    catch (const std::exception& ex) {
        std::string narrow = ex.what();
        result.error.assign(narrow.begin(), narrow.end());
        if (result.error.empty()) {
            result.error = L"Unexpected conversion error.";
        }
        return result;
    }
    catch (...) {
        result.error = L"Unexpected conversion error.";
        return result;
    }
}

std::wstring BuildFailureMessage(const std::vector<ConvertResult>& results) {
    unsigned int failures = 0;
    for (const auto& r : results) {
        if (!r.ok) {
            ++failures;
        }
    }

    if (failures == 0) {
        return {};
    }

    std::wstringstream ss;
    ss << L"PNG to JPG could not convert "
       << failures << L" file"
       << (failures == 1 ? L"" : L"s")
       << L".\n\n";

    unsigned int shown = 0;
    for (const auto& r : results) {
        if (r.ok) {
            continue;
        }

        ss << L"• " << r.input.filename().wstring()
           << L"\n  " << r.error << L"\n";

        if (++shown >= 5) {
            if (failures > shown) {
                ss << L"\n…and " << (failures - shown) << L" more.";
            }
            break;
        }
    }

    return ss.str();
}

} // namespace

int WINAPI wWinMain(
    HINSTANCE,
    HINSTANCE,
    PWSTR,
    int)
{
    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv) {
        return 2;
    }

    bool quiet = false;
    std::vector<fs::path> inputs;

    for (int i = 1; i < argc; ++i) {
        if (_wcsicmp(argv[i], L"--quiet") == 0) {
            quiet = true;
        } else {
            inputs.emplace_back(argv[i]);
        }
    }

    LocalFree(argv);

    if (inputs.empty()) {
        if (!quiet) {
            MessageBoxW(
                nullptr,
                L"Select one or more PNG files in File Explorer, then choose "
                L"“Convert PNG to JPG”.",
                L"WinPebble PNG to JPG",
                MB_OK | MB_ICONINFORMATION);
        }
        return quiet ? 2 : 0;
    }

    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool shouldUninitialize = SUCCEEDED(hr);

    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
        if (!quiet) {
            const std::wstring msg =
                L"Could not initialize Windows imaging services.\n\n" +
                HResultMessage(hr);
            MessageBoxW(
                nullptr,
                msg.c_str(),
                L"WinPebble PNG to JPG",
                MB_OK | MB_ICONERROR);
        }
        return 2;
    }

    ComPtr<IWICImagingFactory> factory;
    hr = CoCreateInstance(
        CLSID_WICImagingFactory,
        nullptr,
        CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&factory));

    if (FAILED(hr)) {
        if (!quiet) {
            const std::wstring msg =
                L"Could not initialize the Windows Imaging Component.\n\n" +
                HResultMessage(hr);
            MessageBoxW(
                nullptr,
                msg.c_str(),
                L"WinPebble PNG to JPG",
                MB_OK | MB_ICONERROR);
        }

        if (shouldUninitialize) {
            CoUninitialize();
        }
        return 2;
    }

    std::vector<ConvertResult> results;
    results.reserve(inputs.size());

    bool allOk = true;
    for (const auto& input : inputs) {
        ConvertResult result = ConvertOne(factory.Get(), input);
        if (!result.ok) {
            allOk = false;
        }
        results.push_back(std::move(result));
    }

    if (!allOk && quiet) {
        const auto message = BuildFailureMessage(results);
        const int size = WideCharToMultiByte(CP_UTF8, 0, message.c_str(), -1, nullptr, 0, nullptr, nullptr);
        std::vector<char> utf8(size);
        WideCharToMultiByte(CP_UTF8, 0, message.c_str(), -1, utf8.data(), size, nullptr, nullptr);
        DWORD written = 0;
        WriteFile(GetStdHandle(STD_ERROR_HANDLE), utf8.data(), size - 1, &written, nullptr);
    }
    if (!allOk && !quiet) {
        const std::wstring message = BuildFailureMessage(results);
        MessageBoxW(
            nullptr,
            message.c_str(),
            L"WinPebble PNG to JPG",
            MB_OK | MB_ICONERROR);
    }

    factory.Reset();

    if (shouldUninitialize) {
        CoUninitialize();
    }

    return allOk ? 0 : 1;
}
