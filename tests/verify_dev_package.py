"""Validate DEV package scoping/payload without installing or trusting anything."""
import sys
import zipfile
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
    assert identity.attrib == {
        'Name': 'WinPebble.PNGToJPG.Dev', 'Publisher': 'CN=WinPebble PNG to JPG Development',
        'Version': '2.0.0.1', 'ProcessorArchitecture': 'x64',
    }
    assert root.find('.//f:TargetDeviceFamily', ns).get('MinVersion') == '10.0.22000.0'
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
print('DEV full MSIX identity, capability, PNG-only command and exact unsigned payload PASS')
