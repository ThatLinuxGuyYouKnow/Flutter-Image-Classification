import 'dart:math';

List<double> softmax(List<double> logits) {
  final expLogits = logits.map((x) => exp(x)).toList();
  final sumExp = expLogits.reduce((a, b) => a + b);
  return expLogits.map((x) => x / sumExp).toList();
}

/// Finds the index of the maximum value in a list.
int argmax(List<double> values) {
  return values.indexOf(values.reduce(max));
}
