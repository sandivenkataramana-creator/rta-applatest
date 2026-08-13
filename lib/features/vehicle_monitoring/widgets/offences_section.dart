import 'package:flutter/material.dart';

/// Card widget that displays the Offences / Irregularities section,
/// including selected offences and the list of available offences.
class OffencesSection extends StatelessWidget {
  final List<Map<String, dynamic>> availableOffences;
  final Iterable<Map<String, dynamic>> selectedOffences;
  final ValueChanged<Map<String, dynamic>> onOffenceSelected;
  final ValueChanged<Map<String, dynamic>> onOffenceRemoved;
  final Widget? manualChallanSection;

  const OffencesSection({
    super.key,
    required this.availableOffences,
    required this.selectedOffences,
    required this.onOffenceSelected,
    required this.onOffenceRemoved,
    this.manualChallanSection,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OFFENCES/IRREGULARITIES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3260),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Selected Offences list
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SELECTED OFFENCES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.grey.shade50,
                        ),
                        child: selectedOffences.isEmpty
                            ? const Center(
                                child: Text(
                                  'No offence selected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black38,
                                  ),
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.all(6),
                                children: selectedOffences.map((offence) {
                                  final offName =
                                      offence['name']?.toString() ?? '';
                                  final offAmt =
                                      offence['amount'] as num? ?? 0.0;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                offName,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F3260),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '₹ ${offAmt.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color: Color(0xFF0D9488),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () =>
                                              onOffenceRemoved(offence),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right: List of offences select options
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIST OF OFFENCES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(6),
                          itemCount: availableOffences.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final off = availableOffences[index];
                            final bool isAlreadySelected =
                                selectedOffences.any(
                              (element) => element['name'] == off['name'],
                            );
                            final offName = off['name']?.toString() ?? '';
                            final offAmt = off['amount'] as num? ?? 0.0;

                            return InkWell(
                              onTap: isAlreadySelected
                                  ? null
                                  : () => onOffenceSelected(off),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isAlreadySelected
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_back,
                                      size: 14,
                                      color: isAlreadySelected
                                          ? Colors.grey
                                          : const Color(0xFF0F3260),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            offName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isAlreadySelected
                                                  ? Colors.grey
                                                  : Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₹ ${offAmt.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: isAlreadySelected
                                                  ? Colors.grey
                                                  : const Color(0xFF0D9488),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (manualChallanSection != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              manualChallanSection!,
            ] else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
