import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CourierPopup extends StatefulWidget {
  final String? awbNumber;
  final double? courierCost;
  final String? courierRemarks;
  final String? courierUpdatedTime;
  final String? courierUpdatedBy;

  const CourierPopup({
    super.key,
    this.awbNumber,
    this.courierCost,
    this.courierRemarks,
    this.courierUpdatedTime,
    this.courierUpdatedBy,
  });

  @override
  State<CourierPopup> createState() => _CourierPopupState();
}

class _CourierPopupState extends State<CourierPopup> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController awbCtrl;
  late TextEditingController costCtrl;
  late TextEditingController remarkCtrl;

  @override
  void initState() {
    super.initState();
    awbCtrl = TextEditingController(text: widget.awbNumber);
    costCtrl = TextEditingController(text: widget.courierCost?.toString());
    remarkCtrl = TextEditingController(text: widget.courierRemarks);
  }

  @override
  void dispose() {
    awbCtrl.dispose();
    costCtrl.dispose();
    remarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Update Courier Info"),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: awbCtrl,
                decoration: InputDecoration(labelText: "AWB Number"),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: costCtrl,
                decoration: InputDecoration(labelText: "Courier Charge"),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: remarkCtrl,
                decoration: InputDecoration(labelText: "Courier Remarks"),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              if (widget.courierUpdatedBy != null ||
                  widget.courierUpdatedTime != null)
                Text.rich(
                  TextSpan(
                    children: [
                      if (widget.courierUpdatedBy != null) ...[
                        const TextSpan(
                          text: "Last Updated by: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: widget.courierUpdatedBy),
                      ],
                      if (widget.courierUpdatedBy != null &&
                          widget.courierUpdatedTime != null)
                        if (widget.courierUpdatedTime != null) ...[
                          const TextSpan(
                            text: " at: ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: widget.courierUpdatedTime),
                        ],
                    ],
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text("Cancel"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text("Submit"),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                "awbNumber": awbCtrl.text,
                "courierCost": double.tryParse(costCtrl.text) ?? 0,
                "courierRemarks": remarkCtrl.text,
              });
            }
          },
        ),
      ],
    );
  }
}
