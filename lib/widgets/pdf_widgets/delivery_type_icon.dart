import 'package:flutter/material.dart';

String getDeliveryTypeLabel(String? deliveryType, String? deliverySalesPerson) {
  if (deliveryType == null) return '';

  if (deliveryType == 'Delivery by Salesperson') {
    return deliverySalesPerson != null && deliverySalesPerson.isNotEmpty
        ? 'Delivery by `$deliverySalesPerson`'
        : 'Delivery by Salesperson';
  }

  return deliveryType;
}

Widget deliveryTypeIcon(
  BuildContext context,
  String? deliveryType,
  String? deliverySalesPerson,
) {
  if (deliveryType == null) return const SizedBox.shrink();

  final Map<String, IconData> iconMap = {
    'Customer Collection': Icons.directions_walk,
    'Courier': Icons.local_shipping,
    'Delivery by Salesperson': Icons.person, // account_circle 👍
  };

  final icon = iconMap[deliveryType];
  if (icon == null) return const SizedBox.shrink();

  return InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                getDeliveryTypeLabel(deliveryType, deliverySalesPerson),
              ),
              /*content: Text(
                getDeliveryTypeLabel(deliveryType, deliverySalesPerson),
                style: const TextStyle(fontSize: 14),
              ),*/
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    },
    child: Icon(icon, color: Colors.deepPurple, size: 20),
  );
}
