import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

const expressDelivery = Icon(
  Symbols.delivery_truck_speed,
  size: 28,
  fill: 1,
  color: Colors.green,
);
//EMULATOR
// const reportUrlConst = 'http://10.0.2.2:8000/';
// const baseUrlConst = 'http://10.0.2.2:8000/api';
// const pusherAuthURl = 'http://10.0.2.2:8000/broadcasting/auth';

//CHROME
// const baseUrlConst = 'http://127.0.0.1:8000/api';
// const pusherAuthURl = 'http://127.0.0.1:8000/broadcasting/auth';

const reportUrlConst = 'https://estore.b2bprint.shop';
const baseUrlConst = 'https://estore.b2bprint.shop/api';
const pusherAuthURl = 'https://estore.b2bprint.shop/broadcasting/auth';

// const reportUrlConst = 'https://dts.bluerhine.com';
// const baseUrlConst = 'https://dts.bluerhine.com/api';
// const pusherAuthURl = 'https://dts.bluerhine.com/broadcasting/auth';

const pusherAPIKey = 'bbdeff4795b5f23b6c08';
const pusherCluster = 'ap2';

// const pusherAPIKey = 'local-app-key';
// const pusherCluster = 'mt1';
// const pusherAuthURl = "http://192.168.0.106:8000/broadcasting/auth";

const appName = "Delivery Tracking System";
const primaryColor = Color(0xFF2697FF);
const secondaryColor = Color(0xFF2A2D3E);
const bgColor = Color(0xFF212332);

const defaultPadding = 16.0;
/*THEME SETTINGS*/
const colorBlack = Color(0xFF000000);

const colorWhite = Color(0xFFFFFFFF);

const colorInitial = Color.fromRGBO(23, 43, 77, 1.0);

const colorPrimary = Color.fromRGBO(94, 114, 228, 1.0);

const colorSecondary = Color.fromRGBO(247, 250, 252, 1.0);

const colorLabel = Color.fromRGBO(254, 36, 114, 1.0);

const colorInfo = Color.fromRGBO(17, 205, 239, 1.0);

const colorError = Color.fromRGBO(245, 54, 92, 1.0);

const colorSuccess = Color.fromRGBO(45, 206, 137, 1.0);

const colorWarning = Color.fromRGBO(251, 99, 64, 1.0);

const colorHeader = Color.fromRGBO(82, 95, 127, 1.0);

const colorbgColorScreen = Color.fromRGBO(248, 249, 254, 1.0);

const colorBorder = Color.fromRGBO(202, 209, 215, 1.0);

const colorInputSuccess = Color.fromRGBO(123, 222, 177, 1.0);

const colorInputError = Color.fromRGBO(252, 179, 164, 1.0);

const colorMuted = Color.fromRGBO(136, 152, 170, 1.0);

//const colorText = Color.fromRGBO(50, 50, 93, 1.0);
const colorText = Color(0xFFFFFFFF);
const Color primaryTeal = Color(0xFF009688);
const Color secondaryTeal = Color(0xFF004D40);
const Color lightTeal1 = Color(0xFFE0F2F1);
const Color lightTeal2 = Color(0xFFB2DFDB);

Color getInvoiceCardBGColor({
  required int invoiceCurrentStatus,
  required int holdStatus,
  Color defaultColor = Colors.white, // Default fallback color
}) {
  if (invoiceCurrentStatus == 8) {
    return Colors.yellow.shade100; // Pale Yellow
  } else if (holdStatus == 9) {
    return Colors.blue.shade100; // Light Blue
  } else if (holdStatus == 10) {
    return Colors.orange.shade100; // Light Orange
  } else {
    return defaultColor; // Use provided fallback
  }
}

// Common: Get Status Icon
IconData getStatusIcon({
  required int invoiceCurrentStatus,
  required int holdStatus,
}) {
  if (invoiceCurrentStatus == 8) {
    return Icons.cancel; // Cancel icon
  } else if (holdStatus == 9) {
    return Icons.lock; // Hold icon
  } else if (holdStatus == 10) {
    return Icons.history; // Reschedule icon
  } else {
    return Icons.no_encryption; // Default icon
  }
}

Icon expectedDelivery({double size = 18, Color color = secondaryTeal}) {
  return Icon(Icons.access_time, size: size, color: color);
}

Icon otherBranchDelivery({double size = 18, Color color = secondaryTeal}) {
  return Icon(Icons.call_split_sharp, size: size, color: color);
}

/*bool isInvoiceDisabled(int invoiceCurrentStatus, int holdStatus, str) {
  return invoiceCurrentStatus == 8 || holdStatus == 9 || holdStatus == 10;
}*/

bool isInvoiceDisabled(
  int invoiceCurrentStatus,
  int holdStatus,
  String? deliveryType,
) {
  // If delivery type is "Delivery by Salesperson", invoice is never disabled
  if (deliveryType == 'Delivery by Salesperson') {
    return true;
  }

  // Otherwise, check status conditions
  return invoiceCurrentStatus == 8 || holdStatus == 9 || holdStatus == 10;
}

bool paymentReceivedForCOD(
  String? deliveryType,
  String? pmtReceived,
  String? codFlag,
) {
  // If deliveryType is null, return true
  if (deliveryType == null) return true;

  // If deliveryType is Customer Collection or Courier AND pmtReceived is not null AND codFlag is '1'
  if ((deliveryType == 'Customer Collection' || deliveryType == 'Courier') &&
      pmtReceived != null &&
      codFlag == '1') {
    return true;
  }
  if ((deliveryType == 'Customer Collection' || deliveryType == 'Courier') &&
      codFlag == '0') {
    return true;
  }

  return false;
}

bool isInvoiceDisabledExcludeReschedule(
  int invoiceCurrentStatus,
  int holdStatus,
) {
  return invoiceCurrentStatus == 8 || holdStatus == 9;
}

Color parseColor(String? colorString) {
  if (colorString == null) {
    return Colors.grey; // Default color if string is null
  }

  switch (colorString) {
    case 'Colors.green':
      return Colors.green;
    case 'Colors.red':
      return Colors.red;
    case 'Colors.blue':
      return Colors.blue;
    case 'Colors.yellow.shade800':
      return Colors.yellow.shade800;
    case 'Colors.orange':
      return Colors.orange;
    case 'Colors.grey':
      return Colors.grey;
    case 'Colors.purple':
      return Colors.purple;
    case 'Colors.brown':
      return Colors.brown;
    default:
      return Colors.black;
  }
}

Color getStatusColor(int status) {
  switch (status) {
    case 1:
      return Colors.grey;
    case 2:
      return Colors.blue;
    case 3:
      return Colors.teal;
    case 4:
      return Colors.orange;
    case 5:
      return Colors.deepOrange;
    case 6:
      return Colors.green;
    case 7:
      return Colors.green.shade900;
    case 11:
      return Colors.deepPurpleAccent.shade100;
    default:
      return Colors.grey;
  }
}
void showInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
}) {
  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text(message, style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

