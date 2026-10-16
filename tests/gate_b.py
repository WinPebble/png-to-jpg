"""Gate B integration tests. Requires Pillow only on the test machine."""
import argparse, concurrent.futures, ctypes, hashlib, json, math, os
from pathlib import Path
import shutil, struct, subprocess, time, zlib, uuid
from PIL import Image, ImageChops, ImageCms, ImageStat

parser=argparse.ArgumentParser(); parser.add_argument('--exe',required=True); parser.add_argument('--root',default='.work/gate-b-'+uuid.uuid4().hex); args=parser.parse_args()
exe=Path(args.exe).resolve(); root=Path(chr(92)*2+'?'+chr(92)+str(Path(args.root).resolve())); root.mkdir(parents=True,exist_ok=False)
results=[]; timings=[]
class MemoryCounters(ctypes.Structure):
    _fields_=[('cb',ctypes.c_ulong),('PageFaultCount',ctypes.c_ulong)]+[(n,ctypes.c_size_t) for n in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage']]
def peak_memory(process):
    counters=MemoryCounters();counters.cb=ctypes.sizeof(counters)
    fn=ctypes.WinDLL('psapi').GetProcessMemoryInfo
    fn.argtypes=[ctypes.c_void_p,ctypes.POINTER(MemoryCounters),ctypes.c_ulong]
    check(fn(int(process._handle),ctypes.byref(counters),counters.cb),'memory query')
    return counters.PeakWorkingSetSize

def check(condition,message):
    if not condition: raise AssertionError(message)
def run(paths, expected=0):
    start=time.perf_counter(); p=subprocess.Popen([str(exe),'--quiet',*map(str,paths)],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    out,err=p.communicate(timeout=120)
    elapsed=time.perf_counter()-start
    timings.append(dict(seconds=elapsed,peak_working_set_bytes=peak_memory(p)))
    check(p.returncode==expected, f'{paths}: exit={p.returncode}: {err.decode("utf-8",errors="replace")}')
    return elapsed

def png(path,w,h,depth,kind,rows,chunks=()):
    def chunk(tag,data): return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    path.write_bytes(bytes([137,80,78,71,13,10,26,10])+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,depth,kind,0,0,0))+b''.join(chunk(t,d) for t,d in chunks)+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b''))

fixtures=[]
def save(name,image,**options):
    path=root/name; path.parent.mkdir(parents=True,exist_ok=True);image.save(path,**options); fixtures.append(path); return path
solid=save('opaque.png',Image.new('RGB',(257,193),(30,120,220)),dpi=(144,144))
alpha=save('alpha.png',Image.new('RGBA',(128,128),(220,40,40,128)))
transparent=save('transparent.png',Image.new('RGBA',(64,64),(70,80,90,0)))
save('nested/Thư mục có dấu/ảnh tiếng Việt.PNG',Image.new('RGB',(77,55),(12,100,250)))
save('gray.png',Image.linear_gradient('L').resize((128,128)))
palette=Image.new('P',(64,64));palette.putpalette([255,0,0,0,255,0]+[0]*762);palette.info['transparency']=bytes([128,0]);save('indexed.png',palette)
for kind,channels in [(0,1),(2,3),(4,2),(6,4)]:
    p=root/f'16bit-{kind}.png';pixel=b''.join(struct.pack('>H',v) for v in ([32768]*channels));png(p,64,64,16,kind,(b'\0'+pixel*64)*64);fixtures.append(p)
icc=ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
save('icc-srgb.png',Image.new('RGB',(128,128),(45,90,135)),icc_profile=icc)
p=root/'gamma.png';png(p,64,64,8,2,(b'\0'+bytes([100,150,200])*64)*64,[(b'gAMA',struct.pack('>I',45455))]);fixtures.append(p)
longdir=root
for n in range(5): longdir=longdir/('nested-'+str(n)+'-'+'x'*48)
save(str(longdir/root.name)+'/long path.png',Image.new('RGB',(41,31),(10,20,30)))
# Deterministic gradients/checker details for encoder and v1 comparison.
w,h=512,384
pattern=Image.new('RGB',(w,h));pattern.putdata([((x*3+y)%256,(x+y*2)%256,((x//8+y//8)%2)*255) for y in range(h) for x in range(w)])
save('detail.png',pattern)
before={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in fixtures}
run(fixtures)
for p in fixtures:
    with Image.open(p) as inp, Image.open(p.with_suffix('.jpg')) as out:
        check(inp.size==out.size,f'dimensions {p}')
        check(all(max(q)==1 for q in out.quantization.values()),f'JPEG maximum quality quantization {p}')
    check(hashlib.sha256(p.read_bytes()).hexdigest()==before[str(p)],f'changed {p}')
results.append('single/batch, Unicode, spaces, nested, >260-char paths, RGB/grayscale/indexed/16-bit, source hashes, JPEG DQT maximum')
for name,expected in [('transparent',(255,255,255)),('alpha',(237,147,147)),('indexed',(255,127,127))]:
    with Image.open(root/(name+'.jpg')) as image:
        pixel=image.getpixel((32,32));check(max(abs(a-b) for a,b in zip(pixel,expected))<=4,f'alpha {name}: {pixel}')
results.append('transparent and partial alpha (including indexed transparency)')
with Image.open(solid.with_suffix('.jpg')) as image: check(abs(image.info['dpi'][0]-144)<1,'DPI')
existing=solid.with_suffix('.jpg');original=existing.read_bytes()
run([solid]);check((root/'opaque (2).jpg').exists(),'collision 2')
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: list(pool.map(lambda _:run([solid]),range(8)))
check(all((root/f'opaque ({i}).jpg').exists() for i in range(2,11)),'concurrent numbering')
check(existing.read_bytes()==original,'overwrite')
results.append('8 concurrent processes after existing (2): contiguous (3)..(10), no overwrite')
# Read-only input remains convertible.
os.chmod(solid,0o444)
try: run([solid])
finally: os.chmod(solid,0o666)
results.append('read-only input')
corrupt=root/'corrupt.png';corrupt.write_bytes(b'not PNG')
mislabeled=root/'mislabeled.png';Image.new('RGB',(32,32)).save(mislabeled,format='JPEG')
truncated=root/'truncated.png';truncated.write_bytes(solid.read_bytes()[:100])
for p in [corrupt,mislabeled,truncated,root/'missing.png',root/'detail.jpg']:
    run([p],1);check(not p.with_suffix('.jpg').exists() or p.suffix=='.jpg',f'bad final {p}')
run([corrupt,transparent],1);run([],2)
results.append('corrupt, mislabeled JPEG, truncated chunks, missing, wrong extension, mixed batch, empty args; no temp orphan')
check(not list(root.rglob('*.tmp')),'orphan temp')
# Finalization failure must close the encoder handle and remove its temp file.
blocked=save('b'*250+'.png',Image.new('RGB',(64,64)))
blocked.with_suffix('.jpg').write_bytes(b'existing')
run([blocked],1)
check(not list(root.rglob('*.tmp')), 'finalization cleanup')
# Deny write only in a dedicated fixture directory; restore in finally.
denied=root/'denied';denied.mkdir();denied_png=denied/'input.png';Image.new('RGB',(64,64)).save(denied_png)
account=subprocess.check_output(['whoami'],text=True).strip()
normal_dir=str(denied)[4:]
try:
    subprocess.run(['icacls',normal_dir,'/deny',account+':(W)'],check=True,capture_output=True)
    run([denied_png],1)
    check(not denied_png.with_suffix('.jpg').exists(),'denied output')
finally:
    subprocess.run(['icacls',normal_dir,'/remove:d',account],check=True,capture_output=True)
results.append('permission denied and finalization failure: no final JPG or orphan temp')
# Compare the exact historical script; each fixture has its own copied folder.
bench=root/'baseline';bench.mkdir(); report=[]
for p in fixtures:
    if p == blocked: continue
    if len(str(p)) > 260: continue  # v1 is not a long-path compatibility promise.
    folder=bench/p.stem;folder.mkdir();copy=folder/p.name;shutil.copyfile(p,copy)
    t=time.perf_counter();r=subprocess.Popen(['powershell.exe','-ExecutionPolicy','Bypass','-NoProfile','-NonInteractive','-File',str(Path('src/ConvertPNGtoJPG.ps1').resolve()),str(copy)[4:]],stdout=subprocess.PIPE,stderr=subprocess.PIPE);_,v1err=r.communicate(timeout=120);v1peak=peak_memory(r);v1time=time.perf_counter()-t
    check(r.returncode==0 and copy.with_suffix('.jpg').exists(),f'v1 missing {p}: {v1err}')
    v2time=run([copy]);a=Image.open(copy.with_suffix('.jpg')).convert('RGB');b=Image.open(folder/(copy.stem+' (2).jpg')).convert('RGB')
    stat=ImageStat.Stat(ImageChops.difference(a,b));rmse=math.sqrt(sum(v*v for v in stat.rms)/3)
    report.append(dict(input=p.name,dimensions=a.size,v1_bytes=copy.with_suffix('.jpg').stat().st_size,v2_bytes=(folder/(copy.stem+' (2).jpg')).stat().st_size,v1_seconds=round(v1time,4),v2_seconds=round(v2time,4),v1_peak_bytes=v1peak,v2_peak_bytes=timings[-1]['peak_working_set_bytes'],rmse_vs_v1=round(rmse,4)))
    a.close();b.close()
results.append('v1 comparison: size, time including process startup, decoded RGB RMSE for all valid fixtures')
# Stress: 24 MP; buffers bounded but codec allocations are measured separately by OS.
stress=save('stress.png',Image.new('RGBA',(6000,4000),(70,120,220,128)));elapsed=run([stress]);check(stress.with_suffix('.jpg').exists(),'stress')
results.append(f'24 MP stress: {elapsed:.3f}s')
check(not list(root.rglob('*.tmp')),'temp after stress')
(root/'report.json').write_text(json.dumps(dict(tests=results,comparisons=report,stress_seconds=elapsed,stress_peak_bytes=timings[-1]['peak_working_set_bytes'],os_version=str(os.sys.getwindowsversion()),exe_sha256=hashlib.sha256(exe.read_bytes()).hexdigest()),indent=2),encoding='utf-8')
print(json.dumps(dict(tests=results,report=str(root/'report.json')),indent=2))

