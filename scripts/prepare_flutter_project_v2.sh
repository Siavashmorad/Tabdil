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
root = Path('lib').resolve()

# Canonical destination for every source file copied into lib/.
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
by_name = {name: root / rel for name, rel in files.items()}

# Convert every local/root-relative Dart URI by resolving it from the importing
# file first. This is intentionally path-aware: '../models/candle.dart' from
# core/analysis/signal_engine.dart resolves to core/models/candle.dart, while
# 'services/trading_controller.dart' from main.dart resolves to services/....
uri_re = re.compile(r"(?P<q>['\"])(?P<uri>[^'\"]+\.dart)(?P=q)")
import_re = re.compile(r"^(?P<prefix>\s*(?:import|export|part)\s+)(?P<uri>['\"])(?P<path>[^'\"]+\.dart)(?P=uri)")

for path in root.rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    out = []
    for line in text.splitlines(keepends=True):
        m = import_re.match(line)
        if not m:
            out.append(line)
            continue
        uri = m.group('path')
        if uri.startswith(('dart:', 'flutter:', 'package:')):
            out.append(line)
            continue

        candidate = (path.parent / uri).resolve() if uri.startswith('.') else (root / uri).resolve()
        target = candidate if candidate.is_file() and str(candidate).startswith(str(root) + '/') else None
        if target is None:
            target = by_name.get(Path(uri).name)

        if target is not None and target.is_file():
            rel = target.relative_to(root).as_posix()
            new_uri = f'package:{PACKAGE}/{rel}'
            start, end = m.span('path')
            line = line[:start] + new_uri + line[end:]
        out.append(line)
    path.write_text(''.join(out), encoding='utf-8')

required = [root / rel for rel in files.values()]
missing = [str(p.relative_to(root)) for p in required if not p.is_file()]
if missing:
    raise SystemExit('Missing generated source(s): ' + ', '.join(missing))

# Fail early if any local Dart URI survived. This catches exactly the class of
# failures that previously produced hundreds of cascading analyzer errors.
remaining = []
for path in root.rglob('*.dart'):
    for line_no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        m = import_re.match(line)
        if m and not m.group('path').startswith(('dart:', 'flutter:', 'package:')):
            remaining.append(f'{path.relative_to(root)}:{line_no}: {line.strip()}')
if remaining:
    print('Unnormalized local Dart imports:')
    print('\n'.join(remaining))
    raise SystemExit(1)

print('Flutter source tree prepared; all local Dart imports resolved to package paths.')
PY

echo 'Flutter source tree prepared successfully.'
