import 'package:flutter_test/flutter_test.dart';
import 'package:potfolio/models.dart';

void main() {
  test('pot value follows prices from entry', () {
    final pot = Pot(
      id: 'p1',
      name: 'Tech',
      goal: Goal.tech,
      amount: 500,
      allocations: const [
        Allocation(symbol: 'AAPL', name: 'Apple', weight: 50, reason: '', entryPrice: 100),
        Allocation(symbol: 'NVDA', name: 'NVIDIA', weight: 50, reason: '', entryPrice: 200),
      ],
      risks: const [],
      createdAt: DateTime(2026, 11, 24),
    );
    // Apple +10%, NVIDIA flat (no price) -> 275 + 250
    expect(pot.valueWith({'AAPL': 110}), closeTo(525, 0.001));
  });

  test('investable only when a Base contract is known', () {
    const a = Stock(symbol: 'AAPL', name: 'Apple', market: Market.us, exchange: 'NASDAQ');
    expect(a.investable, isFalse);
    expect(a.copyWith(contract: '0xabc').investable, isTrue);
  });
}
