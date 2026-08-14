#!/usr/bin/env bash
set -euo pipefail

# Assemble the standard Flutter lib/ tree from the source files currently
# stored at repository root. The source files are deliberately kept at root
# so the existing GitHub-uploaded project remains intact.

rm -rf lib
mkdir -p \
  lib/core/api \
  lib/core/analysis \
  lib/core/models \
  lib/core/risk \
  lib/core/widgets \
  lib/services \
  lib/screens/dashboard \
  lib/screens/trading \
  lib/screens/portfolio \
  lib/screens/settings \
  lib/screens/analysis

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

# candlestick_chart.dart contains imports relative to lib/core/widgets/.
# The previous flat destination (lib/core/widgets_candlestick_chart.dart)
# made ../core/models resolve to a non-existent lib/core/core/models path.
cp candlestick_chart.dart lib/core/widgets/candlestick_chart.dart

cp dashboard_screen.dart lib/screens/dashboard/dashboard_screen.dart
cp trading_screen.dart lib/screens/trading/trading_screen.dart
cp portfolio_screen.dart lib/screens/portfolio/portfolio_screen.dart
cp settings_screen.dart lib/screens/settings/settings_screen.dart
cp analysis_detail_screen.dart lib/screens/analysis/analysis_detail_screen.dart

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

echo "Flutter source tree prepared successfully."
