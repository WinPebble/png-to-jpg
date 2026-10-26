"""Validate DEV package scoping/payload without installing or trusting anything."""
import sys
import zipfile
import json
import base64
import hashlib
from pathlib import Path
import xml.etree.ElementTree as ET

ns = {
    'f': 'http://schemas.microsoft.com/appx/manifest/foundation/windows10',
    'com': 'http://schemas.microsoft.com/appx/manifest/com/windows10',
    'd5': 'http://schemas.microsoft.com/appx/manifest/desktop/windows10/5',
    'r': 'http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities',
}
with zipfile.ZipFile(sys.argv[1]) as archive:
    names = set(archive.namelist())
    expected = {
        'AppxManifest.xml', 'WinPebble.PNGToJPG.exe', 'WinPebble.PNGToJPG.Shell.dll',
        'Assets/StoreLogo.png', 'Assets/Square44x44Logo.png', 'Assets/Square150x150Logo.png',
        'Assets/Command.ico', '[Content_Types].xml', 'AppxBlockMap.xml',
    }
    assert names == expected, names.symmetric_difference(expected)
    root = ET.fromstring(archive.read('AppxManifest.xml'))
    identity = root.find('f:Identity', ns)
    expected_identity = {
        'Name': 'WinPebble.PNGToJPG.Dev', 'Publisher': 'CN=WinPebble PNG to JPG Development',
        'Version': '2.0.1.1', 'ProcessorArchitecture': 'x64',
    }
    store = '--store' in sys.argv[2:]
    if store:
        official = json.loads((Path(__file__).resolve().parents[1] / 'packaging/StoreIdentity.json').read_text())
        expected_identity.update(Name=official['Name'], Publisher=official['Publisher'], Version=official['PackageVersion'])
        assert root.find('f:Properties/f:DisplayName', ns).text == official['ProductName']
        assert root.find('f:Properties/f:PublisherDisplayName', ns).text == official['PublisherDisplayName']
        assert expected_identity['Version'].endswith('.0')
        for name in ['WinPebble.PNGToJPG.exe', 'WinPebble.PNGToJPG.Shell.dll']:
            binary = archive.read(name)
            pe = int.from_bytes(binary[0x3c:0x40], 'little')
            assert binary[pe:pe+4] == b'PE\0\0' and binary[pe+4:pe+6] == b'\x64\x86'
        for name in ['Command.ico', 'StoreLogo.png', 'Square44x44Logo.png', 'Square150x150Logo.png']:
            assert archive.read('Assets/' + name) == (Path(__file__).resolve().parents[1] / 'packaging/Assets' / name).read_bytes()
    assert identity.attrib == expected_identity
    assert root.find('.//f:TargetDeviceFamily', ns).get('MinVersion') == '10.0.19041.0'
    assert root.find('.//f:TargetDeviceFamily', ns).get('Name') == 'Windows.Desktop'
    application = root.find('.//f:Application', ns)
    uap10 = '{http://schemas.microsoft.com/appx/manifest/uap/windows10/10}'
    assert application.get(uap10 + 'RuntimeBehavior') == 'packagedClassicApp'
    assert application.get(uap10 + 'TrustLevel') == 'mediumIL'
    assert root.find('.//f:Application', ns).get('Executable') == 'WinPebble.PNGToJPG.exe'
    classes = root.findall('.//com:Class', ns)
    assert len(classes) == 1 and classes[0].get('Path') == 'WinPebble.PNGToJPG.Shell.dll'
    assert classes[0].get('ThreadingModel') == 'STA'
    types = root.findall('.//d5:ItemType', ns)
    assert len(types) == 1 and types[0].get('Type') == '.png'
    verbs = root.findall('.//d5:Verb', ns)
    assert len(verbs) == 1 and verbs[0].get('Clsid') == classes[0].get('Id') == '331934D2-2EAD-4A03-8FF9-FEFF310D45BB'
    assert [c.get('Name') for c in root.findall('.//r:Capability', ns)] == ['runFullTrust']
    assert 'AllowExternalContent' not in archive.read('AppxManifest.xml').decode('utf-8')
    blockmap = ET.fromstring(archive.read('AppxBlockMap.xml'))
    assert blockmap.get('HashMethod') == 'http://www.w3.org/2001/04/xmlenc#sha256'
    for file in blockmap:
        data = archive.read(file.get('Name').replace('\\', '/'))
        assert len(data) == int(file.get('Size'))
        blocks = file.findall('{http://schemas.microsoft.com/appx/2010/blockmap}Block')
        assert len(blocks) == (len(data) + 65535) // 65536
        for i, block in enumerate(blocks):
            assert base64.b64decode(block.get('Hash')) == hashlib.sha256(data[i*65536:(i+1)*65536]).digest()
        for fullhash in file.findall('{http://schemas.microsoft.com/appx/2021/blockmap}FileHash'):
            assert base64.b64decode(fullhash.get('Hash')) == hashlib.sha256(data).digest()
print(('STORE candidate' if store else 'DEV') + ' full MSIX identity, capability, PNG-only command, block hashes and exact unsigned payload PASS')
