#!/usr/bin/env python3
"""Repeat the TV browse/play/back path and save Android memory evidence."""
import argparse
import json
import pathlib
import re
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--adb', required=True)
parser.add_argument('--serial', required=True)
parser.add_argument('--output', required=True)
parser.add_argument('--cycles', type=int, default=3)
parser.add_argument('--pressure', action='store_true')
args = parser.parse_args()
output = pathlib.Path(args.output)
output.mkdir(parents=True, exist_ok=True)
package = 'com.n3urda.piliplustv'
base = [args.adb, '-s', args.serial]


def adb(*command):
    return subprocess.check_output(base + list(command), text=True, timeout=30)


def keys(codes, delay=0.15):
    for code in codes:
        adb('shell', 'input', 'keyevent', str(code))
        time.sleep(delay)


records = []


def sample(phase):
    activity = adb('shell', 'dumpsys', 'activity', 'activities')
    (output / f'{phase}-activity.txt').write_text(activity)
    resumed = next((line for line in activity.splitlines()
                    if 'topResumedActivity=' in line), '')
    if package not in resumed:
        raise RuntimeError(f'{phase}: app is not foreground: {resumed}')
    raw = adb('shell', 'dumpsys', 'meminfo', package)
    (output / f'{phase}-meminfo.txt').write_text(raw)
    pss = re.search(r'TOTAL PSS:\s*(\d+)', raw)
    rss = re.search(r'TOTAL RSS:\s*(\d+)', raw)
    record = {
        'phase': phase,
        'timestamp': time.time(),
        'pid': adb('shell', 'pidof', package).strip(),
        'pss_kib': int(pss[1]) if pss else None,
        'rss_kib': int(rss[1]) if rss else None,
    }
    with (output / f'{phase}.png').open('wb') as screen:
        subprocess.run(base + ['exec-out', 'screencap', '-p'], stdout=screen,
                       check=True, timeout=30)
    records.append(record)
    (output / 'measurements.json').write_text(json.dumps(records, indent=2))
    print(json.dumps(record), flush=True)


(output / 'system-memory.txt').write_text(adb('shell', 'cat', '/proc/meminfo'))
(output / 'package.txt').write_text(adb('shell', 'dumpsys', 'package', package))
adb('shell', 'am', 'force-stop', package)
time.sleep(2)
adb('logcat', '-c')
adb('shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN',
    '-c', 'android.intent.category.LEANBACK_LAUNCHER',
    '-n', package + '/com.example.piliplus.MainActivity')
time.sleep(7)
sample('01-cold-home')
keys([22])
for _ in range(4):
    keys([22] * 4 + [21] * 4 + [20] * 3 + [19] * 3)
time.sleep(2)
sample('02-browsing')
for cycle in range(1, args.cycles + 1):
    keys([23])
    time.sleep(9)
    sample(f'03-play-{cycle}')
    keys([4])
    time.sleep(3)
    sample(f'04-return-{cycle}')
time.sleep(8)
sample('05-settled')
if args.pressure:
    (output / 'pressure-command.txt').write_text(
        adb('shell', 'am', 'send-trim-memory', package, 'RUNNING_CRITICAL'))
    time.sleep(2)
    sample('06-memory-pressure')
    keys([22, 21])
    time.sleep(6)
    keys([3])
    time.sleep(2)
    (output / 'background-meminfo.txt').write_text(
        adb('shell', 'dumpsys', 'meminfo', package))
    adb('shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN',
        '-c', 'android.intent.category.LEANBACK_LAUNCHER',
        '-n', package + '/com.example.piliplus.MainActivity')
    time.sleep(6)
    sample('07-resumed')
(output / 'logcat.txt').write_text(adb('logcat', '-d', '-v', 'threadtime'))
print('Completed; inspect phase screenshots to confirm playback actually opened.', flush=True)
