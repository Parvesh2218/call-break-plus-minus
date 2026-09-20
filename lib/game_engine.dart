import 'dart:math';

enum Suit { clubs, diamonds, hearts, spades }

extension SuitExtension on Suit {
  String get symbol {
    switch (this) {
      case Suit.clubs: return '♣';
      case Suit.diamonds: return '♦';
      case Suit.hearts: return '♥';
      case Suit.spades: return '♠';
    }
  }

  String get displayName {
    switch (this) {
      case Suit.clubs: return 'Clubs';
      case Suit.diamonds: return 'Diamonds';
      case Suit.hearts: return 'Hearts';
      case Suit.spades: return 'Spades';
    }
  }
}

enum Rank { two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace }

extension RankExtension on Rank {
  int get value => index + 2;

  String get label {
    switch (this) {
      case Rank.two: return '2';
      case Rank.three: return '3';
      case Rank.four: return '4';
      case Rank.five: return '5';
      case Rank.six: return '6';
      case Rank.seven: return '7';
      case Rank.eight: return '8';
      case Rank.nine: return '9';
      case Rank.ten: return '10';
      case Rank.jack: return 'J';
      case Rank.queen: return 'Q';
      case Rank.king: return 'K';
      case Rank.ace: return 'A';
    }
  }
}

class Card {
  const Card(this.suit, this.rank);
  final Suit suit;
  final Rank rank;
  int get value => rank.value;
  @override
  String toString() => rank.label + suit.symbol;
  @override
  bool operator ==(Object other) => other is Card && other.suit == suit && other.rank == rank;
  @override
  int get hashCode => Object.hash(suit, rank);
}

class PlayedCard {
  const PlayedCard({required this.playerIndex, required this.card});
  final int playerIndex;
  final Card card;
}

enum GameMode { classic, indiaTrumpChange }
enum TrumpTieRule { earlierCaller, laterCaller }

class GameRules {
  const GameRules({
    this.mode = GameMode.classic,
    this.minimumTrumpCall = 5,
    this.tieRule = TrumpTieRule.earlierCaller,
    this.fallbackTrump = Suit.spades,
  }) : assert(minimumTrumpCall >= 1 && minimumTrumpCall <= 13);

  final GameMode mode;
  final int minimumTrumpCall;
  final TrumpTieRule tieRule;
  final Suit fallbackTrump;
}

class TrumpDeclaration {
  const TrumpDeclaration({
    required this.playerIndex,
    required this.bid,
    required this.suit,
    required this.callOrder,
  });
  final int playerIndex;
  final int bid;
  final Suit suit;
  final int callOrder;
}

class TrumpResolution {
  const TrumpResolution({required this.trump, this.winningDeclaration});
  final Suit trump;
  final TrumpDeclaration? winningDeclaration;
}

class Deck {
  static List<Card> standard() => [
    for (final suit in Suit.values)
      for (final rank in Rank.values) Card(suit, rank),
  ];

  static List<Card> shuffled([Random? random]) {
    final cards = standard();
    cards.shuffle(random ?? Random());
    return cards;
  }

  static List<List<Card>> dealFourPlayers({Random? random}) {
    final cards = shuffled(random);
    return List.generate(4, (player) =>
      List<Card>.unmodifiable(cards.sublist(player * 13, player * 13 + 13)));
  }
}

TrumpResolution resolveTrump({
  required GameRules rules,
  required List<TrumpDeclaration> declarations,
}) {
  if (rules.mode == GameMode.classic) {
    return const TrumpResolution(trump: Suit.spades);
  }

  final qualifying = declarations.where((d) => d.bid >= rules.minimumTrumpCall).toList();
  if (qualifying.isEmpty) {
    return TrumpResolution(trump: rules.fallbackTrump);
  }

  var winner = qualifying.first;
  for (final candidate in qualifying.skip(1)) {
    if (candidate.bid > winner.bid) {
      winner = candidate;
    } else if (candidate.bid == winner.bid) {
      final candidateWins = rules.tieRule == TrumpTieRule.earlierCaller
          ? candidate.callOrder < winner.callOrder
          : candidate.callOrder > winner.callOrder;
      if (candidateWins) winner = candidate;
    }
  }
  return TrumpResolution(trump: winner.suit, winningDeclaration: winner);
}

List<Card> legalCards({
  required List<Card> hand,
  required List<PlayedCard> trick,
  required Suit trump,
}) {
  if (hand.isEmpty) return const [];
  if (trick.isEmpty) return List<Card>.unmodifiable(hand);

  final leadSuit = trick.first.card.suit;
  final leadCards = hand.where((c) => c.suit == leadSuit).toList();

  if (leadCards.isNotEmpty) {
    final highestLead = _highestCardOfSuit(trick, leadSuit);
    final beating = highestLead == null
        ? <Card>[]
        : leadCards.where((c) => c.value > highestLead.value).toList();
    return List<Card>.unmodifiable(beating.isNotEmpty ? beating : leadCards);
  }

  final trumpCards = hand.where((c) => c.suit == trump).toList();
  if (trumpCards.isEmpty) return List<Card>.unmodifiable(hand);

  final highestTrump = _highestCardOfSuit(trick, trump);
  final beatingTrump = highestTrump == null
      ? <Card>[]
      : trumpCards.where((c) => c.value > highestTrump.value).toList();
  return List<Card>.unmodifiable(beatingTrump.isNotEmpty ? beatingTrump : trumpCards);
}

Card? _highestCardOfSuit(List<PlayedCard> trick, Suit suit) {
  Card? highest;
  for (final played in trick) {
    if (played.card.suit != suit) continue;
    if (highest == null || played.card.value > highest.value) highest = played.card;
  }
  return highest;
}

int trickWinner({required List<PlayedCard> trick, required Suit trump}) {
  if (trick.length != 4) throw ArgumentError('A completed trick must contain exactly 4 cards.');
  final leadSuit = trick.first.card.suit;
  final trumpCards = trick.where((p) => p.card.suit == trump).toList();
  final candidates = trumpCards.isNotEmpty
      ? trumpCards
      : trick.where((p) => p.card.suit == leadSuit).toList();

  var winner = candidates.first;
  for (final candidate in candidates.skip(1)) {
    if (candidate.card.value > winner.card.value) winner = candidate;
  }
  return winner.playerIndex;
}

int scoreRoundTenths({required int bid, required int tricksWon}) {
  if (bid < 1 || bid > 13) throw ArgumentError('Bid must be between 1 and 13.');
  if (tricksWon < 0 || tricksWon > 13) throw ArgumentError('Tricks won must be between 0 and 13.');
  if (tricksWon < bid) return -bid * 10;
  return bid * 10 + (tricksWon - bid);
}

String formatScoreTenths(int tenths) {
  final sign = tenths < 0 ? '-' : '';
  final absolute = tenths.abs();
  return sign + (absolute ~/ 10).toString() + '.' + (absolute % 10).toString();
}

class BotStrategy {
  static int estimateBid(List<Card> hand) {
    var strength = 0.0;
    for (final card in hand) {
      if (card.rank == Rank.ace) {
        strength += 1.0;
      } else if (card.rank == Rank.king) {
        strength += card.suit == Suit.spades ? 0.9 : 0.55;
      } else if (card.rank == Rank.queen) {
        strength += 0.35;
      } else if (card.rank == Rank.jack) {
        strength += 0.15;
      }
      if (card.suit == Suit.spades) strength += 0.08;
    }

    final counts = <Suit, int>{for (final suit in Suit.values) suit: 0};
    for (final card in hand) counts[card.suit] = counts[card.suit]! + 1;
    final longSuitBonus = counts.values.where((n) => n >= 5).length * 0.25;
    return (strength + longSuitBonus).round().clamp(1, 13);
  }

  static Card chooseCard({
    required int playerIndex,
    required List<Card> hand,
    required List<PlayedCard> trick,
    required Suit trump,
  }) {
    final legal = legalCards(hand: hand, trick: trick, trump: trump);
    if (legal.isEmpty) throw StateError('Bot has no legal cards.');

    if (trick.length == 3) {
      final winning = <Card>[];
      for (final card in legal) {
        final testTrick = [
          ...trick,
          PlayedCard(playerIndex: playerIndex, card: card),
        ];
        if (trickWinner(trick: testTrick, trump: trump) == playerIndex) {
          winning.add(card);
        }
      }
      if (winning.isNotEmpty) {
        winning.sort((a, b) => a.value.compareTo(b.value));
        return winning.first;
      }
    }

    final sorted = [...legal]..sort((a, b) {
      final suitCompare = a.suit.index.compareTo(b.suit.index);
      return suitCompare != 0 ? suitCompare : a.value.compareTo(b.value);
    });
    return sorted.first;
  }
}

class RoundEngine {
  RoundEngine({
    required List<List<Card>> hands,
    required List<int> bids,
    required this.trump,
    this.leader = 0,
  })  : hands = hands.map((h) => [...h]).toList(),
        bids = [...bids],
        currentPlayer = leader {
    if (hands.length != 4 || hands.any((h) => h.length != 13)) {
      throw ArgumentError('A round requires four hands of 13 cards.');
    }
    if (bids.length != 4 || bids.any((bid) => bid < 1 || bid > 13)) {
      throw ArgumentError('Four bids between 1 and 13 are required.');
    }
    if (leader < 0 || leader > 3) throw ArgumentError('Leader must be 0-3.');
  }

  final List<List<Card>> hands;
  final List<int> bids;
  final Suit trump;
  final int leader;
  int currentPlayer;
  final List<PlayedCard> currentTrick = [];
  final List<int> tricksWon = [0, 0, 0, 0];
  final List<int> completedTrickWinners = [];

  bool get isComplete => hands.every((h) => h.isEmpty) && currentTrick.isEmpty;

  List<Card> legalCardsForCurrentPlayer() => legalCards(
    hand: hands[currentPlayer],
    trick: currentTrick,
    trump: trump,
  );

  int? playCard(Card card) {
    if (isComplete) throw StateError('Round is already complete.');
    final playerHand = hands[currentPlayer];
    if (!playerHand.contains(card)) throw StateError('Player does not hold this card.');
    if (!legalCardsForCurrentPlayer().contains(card)) {
      throw StateError('Illegal card for the current trick.');
    }

    playerHand.remove(card);
    currentTrick.add(PlayedCard(playerIndex: currentPlayer, card: card));

    if (currentTrick.length < 4) {
      currentPlayer = (currentPlayer + 1) % 4;
      return null;
    }

    final winner = trickWinner(trick: currentTrick, trump: trump);
    tricksWon[winner]++;
    completedTrickWinners.add(winner);
    currentTrick.clear();
    currentPlayer = winner;
    return winner;
  }

  List<int> get roundScoresTenths => [
    for (var player = 0; player < 4; player++)
      scoreRoundTenths(bid: bids[player], tricksWon: tricksWon[player]),
  ];
}

class CallBreakGame {
  CallBreakGame({this.rules = const GameRules(), Random? random})
      : _random = random ?? Random();

  final GameRules rules;
  final Random _random;
  final List<int> totalScoresTenths = [0, 0, 0, 0];
  int _roundsCompleted = 0;

  int get roundsCompleted => _roundsCompleted;
  int get roundNumber => _roundsCompleted + 1;
  bool get isComplete => _roundsCompleted >= 5;
  int leaderForRound(int round) => (round - 1) % 4;

  RoundEngine startRound({
    required List<int> bids,
    required List<TrumpDeclaration> declarations,
  }) {
    if (isComplete) throw StateError('Five rounds are already complete.');
    final resolution = resolveTrump(rules: rules, declarations: declarations);
    return RoundEngine(
      hands: Deck.dealFourPlayers(random: _random),
      bids: bids,
      trump: resolution.trump,
      leader: leaderForRound(roundNumber),
    );
  }

  List<int> finishRound(RoundEngine round) {
    if (!round.isComplete) throw StateError('Round must be complete before scoring.');
    final scores = round.roundScoresTenths;
    for (var i = 0; i < 4; i++) totalScoresTenths[i] += scores[i];
    _roundsCompleted++;
    return [...scores];
  }
}
