"""Observe assertions belonging only to the test process, without changing pmset settings."""
import subprocess
from pathlib import Path

app = Path(__file__).resolve().parent.parent / 'dist/Coffee Time.app/Contents/MacOS/CoffeeTime'
process = subprocess.Popen([str(app), '--power-smoke-test'], stdout=subprocess.PIPE, text=True)
try:
    for stage in ['Buzz', 'Doze', 'Off']:
        line = process.stdout.readline().strip()
        assert line.startswith(stage + ':'), line
        output = subprocess.check_output(['pmset', '-g', 'assertions']).decode('utf-8', errors='replace')
        own = '\n'.join(row for row in output.splitlines() if f'pid {process.pid}(CoffeeTime)' in row)
        if stage == 'Buzz':
            assert 'PreventUserIdleSystemSleep' in own and 'PreventUserIdleDisplaySleep' in own, own
        elif stage == 'Doze':
            assert 'PreventUserIdleSystemSleep' in own and 'PreventUserIdleDisplaySleep' not in own, own
        else:
            assert not own, own
        print(line)
    assert process.wait(timeout=10) == 0
    print('3/3 live IOKit checks passed')
finally:
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=5)
