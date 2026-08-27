import 'package:flutter/material.dart';

/// Card widget that displays the Manual Challan / Additional Offences section,
/// including input fields for custom offence name/amount, add row button,
/// error banner, list of manually added offences, and total challan amount.
class ManualChallanSection extends StatelessWidget {
  final TextEditingController customNameCtrl;
  final TextEditingController customAmountCtrl;
  final List<Map<String, dynamic>> customOffences;
  final double totalChallanAmount;
  final String? addRowError;
  final VoidCallback onAddOffence;
  final ValueChanged<int> onRemoveOffence;
  final VoidCallback onClearError;

  const ManualChallanSection({
    super.key,
    required this.customNameCtrl,
    required this.customAmountCtrl,
    required this.customOffences,
    required this.totalChallanAmount,
    required this.addRowError,
    required this.onAddOffence,
    required this.onRemoveOffence,
    required this.onClearError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MANUAL CHALLAN / ADDITIONAL OFFENCES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F3260),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 500;

                final offenceField = TextField(
                  controller: customNameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Enter Offence Name',
                    hintStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );

                final amountField = TextField(
                  controller: customAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Amount',
                    hintStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );

                final addButton = ElevatedButton(
                  onPressed: onAddOffence,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    '+ Add Row',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );

                final Widget errorBanner = addRowError != null
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFEEBA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFF856404),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  addRowError!,
                                  style: const TextStyle(
                                    color: Color(0xFF856404),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: onClearError,
                                child: const Icon(
                                  Icons.close,
                                  color: Color(0xFF856404),
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink();

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      errorBanner,
                      offenceField,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: amountField),
                          const SizedBox(width: 8),
                          addButton,
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      errorBanner,
                      Row(
                        children: [
                          Expanded(flex: 3, child: offenceField),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: amountField),
                          const SizedBox(width: 12),
                          addButton,
                        ],
                      ),
                    ],
                  );
                }
              },
            ),

            if (customOffences.isNotEmpty) ...[
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: customOffences.length,
                itemBuilder: (context, idx) {
                  final custom = customOffences[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${custom['name']} (₹ ${(custom['amount'] as num).toStringAsFixed(2)})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F3260),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => onRemoveOffence(idx),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 8),

            // Total Challan Amount field on the right
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 450;

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total Challan Amount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 150,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey.shade100,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '₹',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              totalChallanAmount.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Total Challan Amount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 150,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.grey.shade100,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '₹',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                totalChallanAmount.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        );
  }
}
