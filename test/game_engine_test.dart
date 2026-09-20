import 'package:flutter_test/flutter_test.dart';
import 'package:call_break_plus_minus/game_engine.dart';

void main() {
  Card c(Suit s, Rank r) => Card(s, r);

  group('legal cards', () {
    test('lead allows any card', () {
      final hand = [c(Suit.hearts, Rank.two), c(Suit.spades, Rank.ace)];
      expect(legalCards(hand: hand, trick: const [], trump: Suit.spades), hand);
    });

    test('must follow suit', () {
      final hand = [c(Suit.hearts, Rank.two), c(Suit.clubs, Rank.ace)];
      final trick = [PlayedCard(playerIndex: 0, card: c(Suit.hearts, Rank.king))];
      expect(legalCards(hand: hand, trick: trick, trump: Suit.spades),
          [c(Suit.hearts, Rank.two)]);
    });

    test('must beat lead suit when possible', () {
      final hand = [
        c(Suit.hearts, Rank.two),
        c(Suit.hearts, Rank.ace),
        c(Suit.clubs, Rank.ace)
      ];
      final trick = [PlayedCard(playerIndex: 0, card: c(Suit.hearts, Rank.king))];
      expect(legalCards(hand: hand, trick: trick, trump: Suit.spades),
          [c(Suit.hearts, Rank.ace)]);
    });

    test('if unable to beat lead, any lead-suit card is legal', () {
      final hand = [c(Suit.hearts, Rank.two), c(Suit.hearts, Rank.queen), c(Suit.clubs, Rank.ace)];
      final trick = [PlayedCard(playerIndex: 0, card: c(Suit.hearts, Rank.king))];
      expect(legalCards(hand: hand, trick: trick, trump: Suit.spades),
          [c(Suit.hearts, Rank.two), c(Suit.hearts, Rank.queen)]);
    });

    test('void in lead must trump', () {
      final hand = [c(Suit.spades, Rank.two), c(Suit.clubs, Rank.ace)];
      final trick = [PlayedCard(playerIndex: 0, card: c(Suit.hearts, Rank.king))];
      expect(legalCards(hand: hand, trick: trick, trump: Suit.spades),
          [c(Suit.spades, Rank.two)]);
    });

    test('must beat highest trump when possible', () {
      final hand = [c(Suit.spades, Rank.two), c(Suit.spades, Rank.ace), c(Suit.clubs, Rank.ace)];
      final trick = [
        PlayedCard(playerIndex: 0, card: c(Suit.hearts, Rank.king)),
        PlayedCard(playerIndex: 1, card: c(Suit.spades, Rank.king)),
      ];
      expect(legalCards(hand: hand, trick: trick, trump: Suit.spades),
          [c(Suit.spades, Rank.ace)]);
    });

    test('void with no trump allows any card', () {
      final hand = [c(Suit.clubs, Rank.two), c(Suit.diamonds, Rank.ace)];
      final trick = [PlayedCard(playerIndex: 0, card: c(Suit.hearts, Rank.king))];
      expect(legalCards(hand: hand, trick: trick, trump: Suit.spades), hand);
    });
  });

  group('winner and scoring', () {
    test('highest lead suit wins without trump', () {
      final trick = [
        PlayedCard(playerIndex: 0, card: c(Suit.hearts, Rank.ten)),
        PlayedCard(playerIndex: 1, card: c(Suit.hearts, Rank.ace)),
        PlayedCard(playerIndex: 2, card: c(Suit.clubs, Rank.ace)),
        PlayedCard(playerIndex: 3, card: c(Suit.hearts, Rank.king)),
      ];
      expect(trickWinner(trick: trick, trump: Suit.spades), 1);
    });

    test('trump beats non-trump', () {
      final trick = [
        PlayedCard(playerIndex: 0, card: c(Suit.hearts, Rank.ace)),
        PlayedCard(playerIndex: 1, card: c(Suit.spades, Rank.two)),
        PlayedCard(playerIndex: 2, card: c(Suit.hearts, Rank.king)),
        PlayedCard(playerIndex: 3, card: c(Suit.clubs, Rank.ace)),
      ];
      expect(trickWinner(trick: trick, trump: Suit.spades), 1);
    });

    test('highest trump wins', () {
      final trick = [
        PlayedCard(playerIndex: 0, card: c(Suit.spades, Rank.two)),
        PlayedCard(playerIndex: 1, card: c(Suit.spades, Rank.king)),
        PlayedCard(playerIndex: 2, card: c(Suit.spades, Rank.ten)),
        PlayedCard(playerIndex: 3, card: c(Suit.spades, Rank.ace)),
      ];
      expect(trickWinner(trick: trick, trump: Suit.spades), 3);
    });

    test('bid met and extra tricks score correctly', () {
      expect(scoreRoundTenths(bid: 4, tricksWon: 4), 40);
      expect(scoreRoundTenths(bid: 4, tricksWon: 6), 42);
      expect(formatScoreTenths(42), '4.2');
      expect(scoreRoundTenths(bid: 4, tricksWon: 3), -40);
    });
  });

  group('trump resolution', () {
    test('classic always uses spades', () {
      final result = resolveTrump(
        rules: const GameRules(mode: GameMode.classic),
        declarations: const [
          TrumpDeclaration(playerIndex: 0, bid: 13, suit: Suit.hearts, callOrder: 0),
        ],
      );
      expect(result.trump, Suit.spades);
    });

    test('India mode uses fallback when nobody qualifies', () {
      final result = resolveTrump(
        rules: const GameRules(mode: GameMode.indiaTrumpChange),
        declarations: const [
          TrumpDeclaration(playerIndex: 0, bid: 4, suit: Suit.hearts, callOrder: 0),
        ],
      );
      expect(result.trump, Suit.spades);
    });

    test('highest qualifying call selects trump', () {
      final result = resolveTrump(
        rules: const GameRules(mode: GameMode.indiaTrumpChange),
        declarations: const [
          TrumpDeclaration(playerIndex: 0, bid: 5, suit: Suit.hearts, callOrder: 0),
          TrumpDeclaration(playerIndex: 1, bid: 7, suit: Suit.clubs, callOrder: 1),
        ],
      );
      expect(result.trump, Suit.clubs);
      expect(result.winningDeclaration?.playerIndex, 1);
    });

    test('earlier caller wins equal bid by default', () {
      final result = resolveTrump(
        rules: const GameRules(mode: GameMode.indiaTrumpChange),
        declarations: const [
          TrumpDeclaration(playerIndex: 0, bid: 6, suit: Suit.hearts, callOrder: 0),
          TrumpDeclaration(playerIndex: 1, bid: 6, suit: Suit.clubs, callOrder: 1),
        ],
      );
      expect(result.trump, Suit.hearts);
    });

    test('later caller can win configured tie', () {
      final result = resolveTrump(
        rules: const GameRules(
          mode: GameMode.indiaTrumpChange,
          tieRule: TrumpTieRule.laterCaller,
        ),
        declarations: const [
          TrumpDeclaration(playerIndex: 0, bid: 6, suit: Suit.hearts, callOrder: 0),
          TrumpDeclaration(playerIndex: 1, bid: 6, suit: Suit.clubs, callOrder: 1),
        ],
      );
      expect(result.trump, Suit.clubs);
    });

    test('minimum trump call is configurable', () {
      final result = resolveTrump(
        rules: const GameRules(
          mode: GameMode.indiaTrumpChange,
          minimumTrumpCall: 8,
        ),
        declarations: const [
          TrumpDeclaration(playerIndex: 0, bid: 7, suit: Suit.hearts, callOrder: 0),
          TrumpDeclaration(playerIndex: 1, bid: 8, suit: Suit.clubs, callOrder: 1),
        ],
      );
      expect(result.trump, Suit.clubs);
    });
  });

  group('deck, bots, round and game', () {
    test('standard deck has 52 unique cards', () {
      final deck = Deck.standard();
      expect(deck.length, 52);
      expect(deck.toSet().length, 52);
    });

    test('deal gives four hands of 13', () {
      final hands = Deck.dealFourPlayers();
      expect(hands.length, 4);
      expect(hands.every((h) => h.length == 13), isTrue);
      expect(hands.expand((h) => h).toSet().length, 52);
    });

    test('bot bid is in range and bot selects legal card', () {
      final hand = [
        c(Suit.hearts, Rank.two),
        c(Suit.hearts, Rank.ace),
        c(Suit.spades, Rank.ace),
      ];
      expect(BotStrategy.estimateBid(hand), inInclusiveRange(1, 13));
      final trick = [PlayedCard(playerIndex: 0, card: c(Suit.hearts, Rank.king))];
      final chosen = BotStrategy.chooseCard(
        playerIndex: 1,
        hand: hand,
        trick: trick,
        trump: Suit.spades,
      );
      expect(legalCards(hand: hand, trick: trick, trump: Suit.spades), contains(chosen));
    });

    test('round rejects illegal card and winner leads next trick', () {
      final deck = Deck.standard();
      final special = [
        [c(Suit.hearts, Rank.ace), ...deck.where((x) => x != c(Suit.hearts, Rank.ace)).take(12)],
        [c(Suit.hearts, Rank.two), ...deck.where((x) => x != c(Suit.hearts, Rank.ace) && x != c(Suit.hearts, Rank.two)).take(12)],
        [c(Suit.clubs, Rank.ace), ...deck.where((x) => x != c(Suit.hearts, Rank.ace) && x != c(Suit.hearts, Rank.two) && x != c(Suit.clubs, Rank.ace)).take(12)],
        [c(Suit.diamonds, Rank.ace), ...deck.where((x) => x != c(Suit.hearts, Rank.ace) && x != c(Suit.hearts, Rank.two) && x != c(Suit.clubs, Rank.ace) && x != c(Suit.diamonds, Rank.ace)).take(12)],
      ];
      final round = RoundEngine(hands: special, bids: [1, 1, 1, 1], trump: Suit.spades);
      round.playCard(c(Suit.hearts, Rank.ace));
      expect(() => round.playCard(c(Suit.hearts, Rank.ace)), throwsStateError);
      round.playCard(c(Suit.hearts, Rank.two));
      round.playCard(c(Suit.clubs, Rank.ace));
      expect(round.playCard(c(Suit.diamonds, Rank.ace)), 0);
      expect(round.currentPlayer, 0);
    });

    test('five-round game stops after round five', () {
      final game = CallBreakGame();
      for (var i = 0; i < 5; i++) {
        final round = game.startRound(
          bids: [1, 1, 1, 1],
          declarations: const [],
        );
        while (!round.isComplete) {
          final card = BotStrategy.chooseCard(
            playerIndex: round.currentPlayer,
            hand: round.hands[round.currentPlayer],
            trick: round.currentTrick,
            trump: round.trump,
          );
          round.playCard(card);
        }
        game.finishRound(round);
      }
      expect(game.roundsCompleted, 5);
      expect(game.isComplete, isTrue);
      expect(() => game.startRound(
        bids: [1, 1, 1, 1],
        declarations: const [],
      ), throwsStateError);
    });
  });
}
