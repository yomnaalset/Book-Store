import 'package:flutter/material.dart';

class HorizontalStepperExample extends StatefulWidget {
  const HorizontalStepperExample({super.key});

  @override
  State<HorizontalStepperExample> createState() =>
      _HorizontalStepperExampleState();
}

class _HorizontalStepperExampleState extends State<HorizontalStepperExample> {
  int _currentStep = 0;
  Set<int> skippedSteps = {};

  final List<String> steps = ['Shipping', 'Payment', 'Review'];

  bool isStepOptional(int step) => step == 1;
  bool isStepSkipped(int step) => skippedSteps.contains(step);

  void handleNext() {
    setState(() {
      if (isStepSkipped(_currentStep)) skippedSteps.remove(_currentStep);
      if (_currentStep < steps.length - 1) {
        _currentStep++;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All steps completed - you\'re finished!'),
          ),
        );
      }
    });
  }

  void handleBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void handleSkip() {
    if (!isStepOptional(_currentStep)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't skip a non-optional step.")),
      );
      return;
    }
    setState(() {
      skippedSteps.add(_currentStep);
      if (_currentStep < steps.length - 1) _currentStep++;
    });
  }

  void handleReset() {
    setState(() {
      _currentStep = 0;
      skippedSteps.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Checkout Steps")),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: handleNext,
        onStepCancel: handleBack,
        onStepTapped: (index) => setState(() => _currentStep = index),
        steps: steps.asMap().entries.map((entry) {
          int index = entry.key;
          String label = entry.value;

          return Step(
            title: Text(label),
            subtitle: isStepOptional(index)
                ? const Text("Optional", style: TextStyle(fontSize: 10))
                : null,
            content: Text("This is the $label step."),
            isActive: _currentStep >= index,
            state: isStepSkipped(index)
                ? StepState.error
                : (_currentStep > index
                      ? StepState.complete
                      : StepState.indexed),
          );
        }).toList(),
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == steps.length - 1;

          return Row(
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                child: Text(isLastStep ? "Finish" : "Next"),
              ),
              const SizedBox(width: 8),
              if (_currentStep > 0)
                OutlinedButton(
                  onPressed: details.onStepCancel,
                  child: const Text("Back"),
                ),
              const SizedBox(width: 8),
              if (isStepOptional(_currentStep))
                TextButton(onPressed: handleSkip, child: const Text("Skip")),
              if (isLastStep)
                TextButton(onPressed: handleReset, child: const Text("Reset")),
            ],
          );
        },
      ),
    );
  }
}
