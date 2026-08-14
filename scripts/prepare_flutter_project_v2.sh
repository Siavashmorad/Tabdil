#!/usr/bin/env bash
set -euo pipefail

# Build the Flutter tree from the canonical source files at repository root.
# Do not maintain duplicate/simplified model copies under lib: the root files
# are the source of truth.
rm -rf lib
mkdir -p \
  lib/core/api lib/core/analysis lib/core/models lib/core/risk lib/core/widgets \
  lib/services \
  lib/screens/dashboard lib/screens/trading lib/screens/portfolio \
  lib/screens/settings lib/screens/analysis

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

# Canonical package targets. Imports are normalized by imported basename so
# their correctness does not depend on the source file's directory depth.
python3 <<'PY'
from pathlib import Path
import re

mapping = {
    'main.dart': 'package:crypto_trader/main.dart',
    'trading_controller.dart': 'package:crypto_trader/services/trading_controller.dart',
    'tabdeal_api_service.dart': 'package:crypto_trader/core/api/tabdeal_api_service.dart',
    'signal_engine.dart': 'package:crypto_trader/core/analysis/signal_engine.dart',
    'indicators.dart': 'package:crypto_trader/core/analysis/indicators.dart',
    'market_structure.dart': 'package:crypto_trader/core/analysis/market_structure.dart',
    'candlestick_patterns.dart': 'package:crypto_trader/core/analysis/candlestick_patterns.dart',
    'backtester.dart': 'package:crypto_trader/core/analysis/backtester.dart',
    'candle.dart': 'package:crypto_trader/core/models/candle.dart',
    'trade_signal.dart': 'package:crypto_trader/core/models/trade_signal.dart',
    'order_models.dart': 'package:crypto_trader/core/models/order_models.dart',
    'risk_manager.dart': 'package:crypto_trader/core/risk/risk_manager.dart',
    'candlestick_chart.dart': 'package:crypto_trader/core/widgets/candlestick_chart.dart',
    'dashboard_screen.dart': 'package:crypto_trader/screens/dashboard/dashboard_screen.dart',
    'trading_screen.dart': 'package:crypto_trader/screens/trading/trading_screen.dart',
    'portfolio_screen.dart': 'package:crypto_trader/screens/portfolio/portfolio_screen.dart',
    'settings_screen.dart': 'package:crypto_trader/screens/settings/settings_screen.dart',
    'analysis_detail_screen.dart': 'package:crypto_trader/screens/analysis/analysis_detail_screen.dart',
}

pattern = re.compile(r"(['\"])(?!dart:|package:|flutter:)([^'\"]+\.dart)\1")

for path in Path('lib').rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    def replace(match):
        quote, value = match.groups()
        name = value.rsplit('/', 1)[-1]
        target = mapping.get(name)
        if target:
            return f"{quote}{target}{quote}"
        return match.group(0)
    updated = pattern.sub(replace, text)
    path.write_text(updated, encoding='utf-8')
PY

required=(
  lib/main.dart
  lib/services/trading_controller.dart
  lib/core/api/tabdeal_api_service.dart
  lib/core/analysis/signal_engine.dart
  lib/core/analysis/indicators.dart
  lib/core/analysis/market_structure.dart
  lib/core/analysis/candlestick_patterns.dart
  lib/core/analysis/backtester.dart
  lib/core/models/candle.dart
  lib/core/models/trade_signal.dart
  lib/core/models/order_models.dart
  lib/core/risk/risk_manager.dart
  lib/core/widgets/candlestick_chart.dart
  lib/screens/dashboard/dashboard_screen.dart
  lib/screens/trading/trading_screen.dart
  lib/screens/portfolio/portfolio_screen.dart
  lib/screens/settings/settings_screen.dart
  lib/screens/analysis/analysis_detail_screen.dart
)

for file in "${required[@]}"; do
  test -f "$file" || { echo "Missing generated source: $file"; exit 1; }
done

echo "Flutter source tree prepared from canonical root sources; imports normalized to package paths."
