#!/usr/bin/env bash
set -euo pipefail

rm -rf lib
mkdir -p lib/core/{api,analysis,models,risk,widgets} lib/services lib/screens/{dashboard,trading,portfolio,settings,analysis}

cp main.dart lib/main.dart
cp trading_controller.dart lib/services/trading_controller.dart
cp tabdeal_api_service.dart lib/core/api/tabdeal_api_service.dart
cp signal_engine.dart lib/core/analysis/signal_engine.dart
cp indicators.dart lib/core/analysis/indicators.dart
cp market_structure.dart lib/core/analysis/market_structure.dart
cp candlestick_patterns.dart lib/core/analysis/candlestick_patterns.dart
cp backtester.dart lib/core/analysis/backtester.dart
cp candle.dart lib/core/models/candle.dart
cp trade_signal.dart lib/core/models/trade_signal.dart
cp order_models.dart lib/core/models/order_models.dart
cp risk_manager.dart lib/core/risk/risk_manager.dart
cp candlestick_chart.dart lib/core/widgets/candlestick_chart.dart
cp dashboard_screen.dart lib/screens/dashboard/dashboard_screen.dart
cp trading_screen.dart lib/screens/trading/trading_screen.dart
cp portfolio_screen.dart lib/screens/portfolio/portfolio_screen.dart
cp settings_screen.dart lib/screens/settings/settings_screen.dart
cp analysis_detail_screen.dart lib/screens/analysis/analysis_detail_screen.dart

python3 - <<'PY'
from pathlib import Path
import re

PACKAGE = 'crypto_trader'
root = Path('lib')

files = {
    'main.dart': 'main.dart',
    'trading_controller.dart': 'services/trading_controller.dart',
    'tabdeal_api_service.dart': 'core/api/tabdeal_api_service.dart',
    'signal_engine.dart': 'core/analysis/signal_engine.dart',
    'indicators.dart': 'core/analysis/indicators.dart',
    'market_structure.dart': 'core/analysis/market_structure.dart',
    'candlestick_patterns.dart': 'core/analysis/candlestick_patterns.dart',
    'backtester.dart': 'core/analysis/backtester.dart',
    'candle.dart': 'core/models/candle.dart',
    'trade_signal.dart': 'core/models/trade_signal.dart',
    'order_models.dart': 'core/models/order_models.dart',
    'risk_manager.dart': 'core/risk/risk_manager.dart',
    'candlestick_chart.dart': 'core/widgets/candlestick_chart.dart',
    'dashboard_screen.dart': 'screens/dashboard/dashboard_screen.dart',
    'trading_screen.dart': 'screens/trading/trading_screen.dart',
    'portfolio_screen.dart': 'screens/portfolio/portfolio_screen.dart',
    'settings_screen.dart': 'screens/settings/settings_screen.dart',
    'analysis_detail_screen.dart': 'screens/analysis/analysis_detail_screen.dart',
}

line_re = re.compile(r"^(\s*(?:import|export|part)\s+['\"])([^'\"]+\.dart)(['\"])(.*)$")

for path in root.rglob('*.dart'):
    output = []
    changed = False
    for raw in path.read_text(encoding='utf-8').splitlines(keepends=True):
        newline = '\n' if raw.endswith('\n') else ''
        line = raw[:-1] if newline else raw
        m = line_re.match(line)
        if not m:
            output.append(raw)
            continue
        prefix, uri, quote, suffix = m.groups()
        if uri.startswith(('dart:', 'flutter:', 'package:')):
            output.append(raw)
            continue
        destination = files.get(Path(uri).name)
        if destination:
            output.append(f'{prefix}package:{PACKAGE}/{destination}{quote}{suffix}{newline}')
            changed = True
        else:
            output.append(raw)
    if changed:
        path.write_text(''.join(output), encoding='utf-8')

required = [root / rel for rel in files.values()]
missing = [str(p) for p in required if not p.is_file()]
if missing:
    raise SystemExit('Missing generated source(s): ' + ', '.join(missing))

remaining = []
for path in root.rglob('*.dart'):
    for line_no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        m = line_re.match(line)
        if m and not m.group(2).startswith(('dart:', 'flutter:', 'package:')):
            remaining.append(f'{path}:{line_no}: {line.strip()}')
if remaining:
    print('Unnormalized local Dart imports:')
    print('\n'.join(remaining))
    raise SystemExit(1)

print('Flutter source tree prepared; all local Dart imports canonicalized to package paths.')
PY

echo 'Flutter source tree prepared successfully.'
