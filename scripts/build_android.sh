#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_project_root="$PWD"
task_sdk_root="${ANDROID_SDK_ROOT:-/workspace/.android-build/sdk}"
task_java_root="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
task_key_path="${ASTRAL_DEBUG_KEYSTORE:-/workspace/.android-build/debug.keystore}"
export XDG_DATA_HOME="$task_project_root/.runtime/data"
export XDG_CONFIG_HOME="$task_project_root/.runtime/config"
export XDG_CACHE_HOME="$task_project_root/.runtime/cache"
export JAVA_HOME="$task_java_root"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME/godot" "$XDG_CACHE_HOME" build
if [[ ! -f "$task_sdk_root/build-tools/36.0.0/apksigner" || ! -f "$task_sdk_root/platform-tools/adb" || ! -f "$task_java_root/bin/java" ]]; then
    echo 'Requires Android build-tools 36.0.0, platform-tools and a Java runtime with keytool.' >&2
    exit 1
fi
if [[ ! -f "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable/android_debug.apk" ]]; then
    echo 'Install Godot 4.6.3 android_debug.apk in .runtime/data/godot/export_templates/4.6.3.stable/.' >&2
    exit 1
fi
if [[ ! -f "$task_key_path" ]]; then
    mkdir -p "$(dirname "$task_key_path")"
    "$task_java_root/bin/keytool" -genkeypair -keystore "$task_key_path" -storetype JKS \
        -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 \
        -validity 10000 -dname 'CN=Astral Frontier Debug,OU=Development,O=Astral Frontier,C=US'
fi
python3 - "$task_sdk_root" "$task_java_root" "$task_key_path" <<'PY'
from pathlib import Path
import os,sys,json,re
p=Path(os.environ['XDG_CONFIG_HOME'])/'godot/editor_settings-4.6.tres'
s=p.read_text() if p.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
settings={'export/android/android_sdk_path':sys.argv[1], 'export/android/java_sdk_path':sys.argv[2],
          'export/android/debug_keystore':sys.argv[3], 'export/android/debug_keystore_user':'androiddebugkey',
          'export/android/debug_keystore_pass':'android'}
for key,value in settings.items():
    s=re.sub(r'^'+re.escape(key)+r'\s*=.*\n','',s,flags=re.M)
    s+=key+' = '+json.dumps(value)+'\n'
p.write_text(s)
PY
godot --headless --editor --import --quit > .runtime/android-import.log 2>&1
if rg 'SCRIPT ERROR|Parse Error|Compile Error' .runtime/android-import.log; then exit 1; fi
godot --headless --path . --export-debug Android build/astral-frontier-debug.apk > .runtime/android-export.log 2>&1
if rg 'SCRIPT ERROR|ERROR:|Export failed' .runtime/android-export.log; then exit 1; fi
"$task_sdk_root/build-tools/36.0.0/apksigner" verify --verbose build/astral-frontier-debug.apk
"$task_sdk_root/build-tools/36.0.0/zipalign" -c -P 16 4 build/astral-frontier-debug.apk
"$task_sdk_root/build-tools/36.0.0/aapt" dump badging build/astral-frontier-debug.apk > build/apk-info.txt
python3 - <<'PY'
from pathlib import Path
import hashlib,zipfile
p=Path('build/astral-frontier-debug.apk')
with zipfile.ZipFile(p) as z:
    assert z.testzip() is None, 'ZIP integrity failure'
    assert 'lib/arm64-v8a/libgodot_android.so' in z.namelist()
    assert not any('.runtime/' in n or '.keystore' in n for n in z.namelist())
Path('build/astral-frontier-debug.apk.sha256').write_text(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n')
print('APK ready:',p.resolve(),'bytes:',p.stat().st_size)
PY
