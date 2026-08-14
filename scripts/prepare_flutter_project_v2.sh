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

# Canonical destination for every project-local Dart source generated above.
# Matching by basename is intentional: all source files in this generated tree
# are unique by basename and the original files are flattened at repository root.
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

# Replace the URI itself, independently of how many ../ segments were present.
# This also handles imports such as "services/foo.dart" from main.dart.
uri_pattern = re.compile(r"(?P<quote>['\"])(?P<uri>[^'\"]+\.dart)(?P=quote)")

def rewrite(text: str) -> tuple[str, int]:
    changes = 0
    def repl(match: re.Match[str]) -> str:
        nonlocal changes
        uri = match.group('uri')
        if uri.startswith(('dart:', 'flutter:', 'package:')):
            return match.group(0)
        name = Path(uri).name
        destination = CANONICAL.get(name)
        if destination is None:
            return match.group(0)
        changes += 1
        return f"{match.group('quote')}package:{PACKAGE}/{destination}{match.group('quote')}"
    return uri_pattern.sub(repl, text), changes

changed_total = 0
for path in root.rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    rewritten, changes = rewrite(text)
    if changes:
        path.write_text(rewritten, encoding='utf-8')
        changed_total += changes

# Fail early if any project-local Dart URI survived normalization.
remaining = []
for path in root.rglob('*.dart'):
    for line_no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        for match in uri_pattern.finditer(line):
            uri = match.group('uri')
            if not uri.startswith(('dart:', 'flutter:', 'package:')) and Path(uri).name in CANONICAL:
                remaining.append(f'{path}:{line_no}: {uri}')

if remaining:
    raise SystemExit('Local project imports remain after normalization:\n' + '\n'.join(remaining))

required = [root / destination for destination in CANONICAL.values()]
missing = [str(path) for path in required if not path.is_file()]
if missing:
    raise SystemExit('Missing generated Dart source(s): ' + ', '.join(missing))

print(f'Canonical Flutter source tree prepared; normalized {changed_total} local Dart import URI(s).')
PY

echo 'Flutter source tree prepared successfully.'
