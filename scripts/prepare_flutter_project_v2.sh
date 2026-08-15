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
CANONICAL = {
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

directive = re.compile(
    r"(?m)^(?P<prefix>\s*(?:import|export|part(?:\s+of)?)\s+)"
    r"(?P<quote>['\"])(?P<uri>[^'\"]+)(?P=quote)(?P<suffix>[^;]*;?)"
)

changed = 0
for path in root.rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    def repl(m):
        nonlocal_changed = None
        uri = m.group('uri')
        if uri.startswith(('dart:', 'flutter:', 'package:')):
            return m.group(0)
        destination = CANONICAL.get(Path(uri).name)
        if destination is None or not uri.endswith('.dart'):
            return m.group(0)
        global changed
        changed += 1
        return f"{m.group('prefix')}{m.group('quote')}package:{PACKAGE}/{destination}{m.group('quote')}{m.group('suffix')}"
    rewritten = directive.sub(repl, text)
    path.write_text(rewritten, encoding='utf-8')

main = root / 'main.dart'
main_text = main.read_text(encoding='utf-8')
main_text = main_text.replace('static const _screens = [', 'static final _screens = [')
main.write_text(main_text, encoding='utf-8')

remaining = []
for path in root.rglob('*.dart'):
    for line_no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        m = directive.match(line)
        if not m:
            continue
        uri = m.group('uri')
        if not uri.startswith(('dart:', 'flutter:', 'package:')) and Path(uri).name in CANONICAL:
            remaining.append(f'{path}:{line_no}: {uri}')
if remaining:
    raise SystemExit('Local project Dart imports remain:\n' + '\n'.join(remaining))

required = [root / p for p in CANONICAL.values()]
missing = [str(p) for p in required if not p.is_file()]
if missing:
    raise SystemExit('Missing generated Dart source(s): ' + ', '.join(missing))

print(f'Canonical Flutter source tree prepared; normalized {changed} local Dart import(s).')
PY

# The repository stores the original Dart sources at the repository root as
# staging inputs. They must not remain in the package root, otherwise
# `flutter analyze` analyzes them too and reports their obsolete relative
# imports in addition to the canonical lib/ tree.
find . -maxdepth 1 -type f -name '*.dart' -delete

echo 'Flutter source tree prepared successfully; legacy root Dart sources removed from analysis.'
