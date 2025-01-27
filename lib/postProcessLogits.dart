import 'dart:math';

List<double> softmax(List<double> input) {
  // Find the maximum value to prevent overflow
  double maxVal = input.reduce((curr, next) => curr > next ? curr : next);

  // Calculate exp of each element after subtracting max
  List<double> expValues = input.map((x) => exp(x - maxVal)).toList();

  // Calculate sum of all exp values
  double sumExp = expValues.reduce((a, b) => a + b);

  // Calculate softmax values
  return expValues.map((x) => x / sumExp).toList();
}

int argmax(List<double> input) {
  if (input.isEmpty) return -1;

  double maxValue = input[0];
  int maxIndex = 0;

  for (int i = 1; i < input.length; i++) {
    if (input[i] > maxValue) {
      maxValue = input[i];
      maxIndex = i;
    }
  }

  return maxIndex;
}
