#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shobjidl.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <wrl/client.h>
#include <iostream>
#include <stdexcept>
#include <vector>
using Microsoft::WRL::ComPtr;
const CLSID CommandId = {0x331934d2,0x2ead,0x4a03,{0x8f,0xf9,0xfe,0xff,0x31,0x0d,0x45,0xbb}};
void Check(bool ok, const char* message) { if (!ok) throw std::runtime_error(message); }
int wmain(int argc, wchar_t** argv) {
    if (argc < 3) return 2;
    const bool registered = wcscmp(argv[1], L"--registered") == 0;
    const bool invoke = wcscmp(argv[2], L"--invoke") == 0;
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    HMODULE module = nullptr;
    int code = 0;
    try {
        ComPtr<IExplorerCommand> command;
        if (registered) {
            Check(SUCCEEDED(CoCreateInstance(CommandId, nullptr, CLSCTX_LOCAL_SERVER, IID_PPV_ARGS(&command))), "registered activation");
        } else {
            module = LoadLibraryW(argv[1]);
            Check(module != nullptr, "LoadLibrary");
            const auto getClass = reinterpret_cast<HRESULT(STDAPICALLTYPE*)(REFCLSID,REFIID,void**)>(GetProcAddress(module,"DllGetClassObject"));
            const auto unload = reinterpret_cast<HRESULT(STDAPICALLTYPE*)()>(GetProcAddress(module,"DllCanUnloadNow"));
            Check(getClass && unload, "COM exports");
            Check(unload() == S_OK, "initial unload state");
            void* missing = reinterpret_cast<void*>(1);
            Check(getClass(GUID_NULL, IID_IClassFactory, &missing) == CLASS_E_CLASSNOTAVAILABLE && !missing,"wrong CLSID");
            Check(getClass(CommandId, IID_IClassFactory, nullptr) == E_POINTER,"null class output");
            ComPtr<IClassFactory> factory;
            Check(SUCCEEDED(getClass(CommandId,IID_PPV_ARGS(&factory))),"class factory");
            Check(unload() == S_FALSE,"factory lifetime");
            factory->LockServer(TRUE);
            factory->LockServer(FALSE);
            Check(SUCCEEDED(factory->CreateInstance(nullptr,IID_PPV_ARGS(&command))),"command creation");
            missing = reinterpret_cast<void*>(1);
            Check(factory->CreateInstance(factory.Get(), __uuidof(IExplorerCommand), &missing) == CLASS_E_NOAGGREGATION && !missing,"aggregation");
            Check(command->GetTitle(nullptr,nullptr) == E_POINTER,"title null");
            Check(command->GetState(nullptr,FALSE,nullptr) == E_POINTER,"state null");
            Check(command->Invoke(nullptr,nullptr) == E_INVALIDARG,"null invocation");
        }
        PWSTR title = nullptr;
        Check(SUCCEEDED(command->GetTitle(nullptr,&title)) && wcscmp(title,L"Convert PNG to JPG") == 0,"title");
        CoTaskMemFree(title);
        GUID id{}; Check(SUCCEEDED(command->GetCanonicalName(&id)) && id == CommandId,"canonical name");
        EXPCMDFLAGS flags{}; Check(SUCCEEDED(command->GetFlags(&flags)) && flags == ECF_DEFAULT,"flags");
        EXPCMDSTATE state{};
        Check(SUCCEEDED(command->GetState(nullptr,TRUE,&state)) && state == ECS_HIDDEN,"empty hidden");
        ComPtr<IShellItemArray> items;
        if (argc > 3) {
            std::vector<PIDLIST_ABSOLUTE> ids;
            for (int i = 3; i < argc; ++i) {
                auto pidl = ILCreateFromPathW(argv[i]);
                Check(pidl != nullptr,"fixture PIDL"); ids.push_back(pidl);
            }
            const HRESULT hr = SHCreateShellItemArrayFromIDLists(static_cast<UINT>(ids.size()),const_cast<PCIDLIST_ABSOLUTE*>(ids.data()), &items);
            for (auto pidl : ids) ILFree(pidl);
            Check(SUCCEEDED(hr),"shell item array");
            Check(SUCCEEDED(command->GetState(items.Get(),TRUE,&state)),"selection state");
            const bool hidden = wcscmp(argv[2], L"--hidden") == 0;
            Check(state == static_cast<EXPCMDSTATE>(hidden ? ECS_HIDDEN : ECS_ENABLED),"selection visibility");
            if (hidden) Check(FAILED(command->Invoke(items.Get(),nullptr)),"reject invalid selection");
            if (invoke) Check(SUCCEEDED(command->Invoke(items.Get(),nullptr)),"launch core");
        }
        command.Reset();
        if (module) {
            const auto unload = reinterpret_cast<HRESULT(STDAPICALLTYPE*)()>(GetProcAddress(module,"DllCanUnloadNow"));
            Check(unload() == S_OK,"no leaked COM objects");
        }
        std::cout << "Shell probe PASS\n";
    } catch (const std::exception& error) { std::cerr << error.what() << '\n'; code = 1; }
    if (module) FreeLibrary(module);
    CoUninitialize(); return code;
}
