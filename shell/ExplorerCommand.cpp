#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <shobjidl.h>
#include <shlwapi.h>
#include <wrl/client.h>
#include <atomic>
#include <new>
#include <string>
#include <vector>

using Microsoft::WRL::ComPtr;
namespace {
// Dedicated PNG-to-JPG CLSID; synchronized with the development manifest.
const CLSID CommandId = {0x331934d2, 0x2ead, 0x4a03, {0x8f,0xf9,0xfe,0xff,0x31,0x0d,0x45,0xbb}};
HMODULE module;
std::atomic<long> objects{0}, locks{0};

template<class F> HRESULT Guard(F&& work) noexcept {
    try { return work(); }
    catch (const std::bad_alloc&) { return E_OUTOFMEMORY; }
    catch (...) { return E_FAIL; }
}

std::wstring Directory() {
    wchar_t path[32768]{};
    const DWORD count = GetModuleFileNameW(module, path, ARRAYSIZE(path));
    if (!count || count >= ARRAYSIZE(path)) return {};
    std::wstring result(path, count);
    return result.substr(0, result.find_last_of(L"\\/"));
}

HRESULT Selection(IShellItemArray* items, std::vector<std::wstring>& paths) {
    if (!items) return E_INVALIDARG;
    DWORD count = 0;
    HRESULT hr = items->GetCount(&count);
    if (FAILED(hr)) return hr;
    if (!count) return E_INVALIDARG;
    for (DWORD i = 0; i < count; ++i) {
        ComPtr<IShellItem> item;
        hr = items->GetItemAt(i, &item);
        if (FAILED(hr)) return hr;
        SFGAOF attributes = 0;
        hr = item->GetAttributes(SFGAO_FILESYSTEM | SFGAO_FOLDER, &attributes);
        if (FAILED(hr)) return hr;
        if (!(attributes & SFGAO_FILESYSTEM) || (attributes & SFGAO_FOLDER)) return E_INVALIDARG;
        PWSTR raw = nullptr;
        hr = item->GetDisplayName(SIGDN_FILESYSPATH, &raw);
        if (FAILED(hr)) return hr;
        // Release the COM allocation even if the C++ allocation throws.
        struct Free { PWSTR p; ~Free() { CoTaskMemFree(p); } } free{raw};
        if (_wcsicmp(PathFindExtensionW(raw), L".png")) return E_INVALIDARG;
        paths.emplace_back(raw);
    }
    return S_OK;
}

HRESULT Launch(const std::vector<std::wstring>& paths) {
    const auto directory = Directory();
    if (directory.empty()) return E_FAIL;
    const auto exe = directory + L"\\WinPebble.PNGToJPG.exe";
    std::wstring args = L"\"" + exe + L"\"";
    // Explorer filesystem names cannot contain quotes or end in a backslash
    // after .png. Pass an explicit application path; never involve a shell.
    for (const auto& path : paths) args += L" \"" + path + L"\"";
    if (args.size() + 1 > 32767) {
        MessageBoxW(nullptr, L"Too many selected paths for one conversion. Please select a smaller batch.",
            L"WinPebble PNG to JPG", MB_OK | MB_ICONERROR);
        return HRESULT_FROM_WIN32(ERROR_BUFFER_OVERFLOW);
    }
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    if (!CreateProcessW(exe.c_str(), args.data(), nullptr, nullptr, FALSE,
            CREATE_NO_WINDOW, nullptr, directory.c_str(), &startup, &process)) {
        const DWORD error = GetLastError();
        MessageBoxW(nullptr, L"Could not start PNG to JPG. Repair or reinstall the application and try again.",
            L"WinPebble PNG to JPG", MB_OK | MB_ICONERROR);
        return HRESULT_FROM_WIN32(error);
    }
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return S_OK; // Do not wait for decoding/conversion on the shell thread.
}

class Command final : public IExplorerCommand {
    std::atomic<ULONG> refs{1};
public:
    Command() { ++objects; }
    ~Command() { --objects; }
    IFACEMETHODIMP QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (iid != IID_IUnknown && iid != __uuidof(IExplorerCommand)) return E_NOINTERFACE;
        *out = static_cast<IExplorerCommand*>(this); AddRef(); return S_OK;
    }
    IFACEMETHODIMP_(ULONG) AddRef() override { return ++refs; }
    IFACEMETHODIMP_(ULONG) Release() override {
        const ULONG remaining = --refs;
        if (!remaining) delete this;
        return remaining;
    }
    IFACEMETHODIMP GetTitle(IShellItemArray*, PWSTR* title) override {
        if (!title) return E_POINTER;
        return SHStrDupW(L"Convert PNG to JPG", title);
    }
    IFACEMETHODIMP GetIcon(IShellItemArray*, PWSTR* icon) override {
        if (!icon) return E_POINTER;
        *icon = nullptr;
        return Guard([&] { return SHStrDupW((Directory() + L"\\Assets\\Command.ico").c_str(), icon); });
    }
    IFACEMETHODIMP GetToolTip(IShellItemArray*, PWSTR* tip) override {
        if (!tip) return E_POINTER;
        *tip = nullptr; return E_NOTIMPL;
    }
    IFACEMETHODIMP GetCanonicalName(GUID* id) override {
        if (!id) return E_POINTER;
        *id = CommandId; return S_OK;
    }
    IFACEMETHODIMP GetState(IShellItemArray* items, BOOL, EXPCMDSTATE* state) override {
        if (!state) return E_POINTER;
        *state = ECS_HIDDEN;
        return Guard([&] {
            std::vector<std::wstring> paths;
            if (SUCCEEDED(Selection(items, paths))) *state = ECS_ENABLED;
            return S_OK;
        }); // Selection metadata only: never decode or inspect file contents.
    }
    IFACEMETHODIMP Invoke(IShellItemArray* items, IBindCtx*) override {
        return Guard([&] {
            std::vector<std::wstring> paths;
            HRESULT hr = Selection(items, paths);
            return FAILED(hr) ? hr : Launch(paths);
        });
    }
    IFACEMETHODIMP GetFlags(EXPCMDFLAGS* flags) override {
        if (!flags) return E_POINTER;
        *flags = ECF_DEFAULT; return S_OK;
    }
    IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** commands) override {
        if (!commands) return E_POINTER;
        *commands = nullptr; return E_NOTIMPL;
    }
};

class Factory final : public IClassFactory {
    std::atomic<ULONG> refs{1};
public:
    Factory() { ++objects; }
    ~Factory() { --objects; }
    IFACEMETHODIMP QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (iid != IID_IUnknown && iid != IID_IClassFactory) return E_NOINTERFACE;
        *out = static_cast<IClassFactory*>(this); AddRef(); return S_OK;
    }
    IFACEMETHODIMP_(ULONG) AddRef() override { return ++refs; }
    IFACEMETHODIMP_(ULONG) Release() override {
        const ULONG remaining = --refs;
        if (!remaining) delete this;
        return remaining;
    }
    IFACEMETHODIMP CreateInstance(IUnknown* outer, REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (outer) return CLASS_E_NOAGGREGATION;
        auto* command = new (std::nothrow) Command;
        if (!command) return E_OUTOFMEMORY;
        const HRESULT hr = command->QueryInterface(iid, out);
        command->Release(); return hr;
    }
    IFACEMETHODIMP LockServer(BOOL lock) override {
        if (lock) ++locks; else --locks;
        return S_OK;
    }
};
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) module = instance;
    // Static CRT uses thread notifications; do not disable them with /MT.
    return TRUE;
}
STDAPI DllCanUnloadNow() { return objects == 0 && locks == 0 ? S_OK : S_FALSE; }
STDAPI DllGetClassObject(REFCLSID clsid, REFIID iid, void** out) {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (clsid != CommandId) return CLASS_E_CLASSNOTAVAILABLE;
    auto* factory = new (std::nothrow) Factory;
    if (!factory) return E_OUTOFMEMORY;
    const HRESULT hr = factory->QueryInterface(iid, out);
    factory->Release(); return hr;
}
