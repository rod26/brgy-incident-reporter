// lib/screens/accident_report_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class AccidentReportScreen extends StatefulWidget {
  const AccidentReportScreen({super.key});
  static const routeName = '/accident-report';

  @override
  State<AccidentReportScreen> createState() => _AccidentReportScreenState();
}

class _AccidentReportScreenState extends State<AccidentReportScreen> {
  final _formKey             = GlobalKey<FormState>();
  final _locationCtrl        = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  String?  _selectedType;
  final _descriptionCtrl     = TextEditingController();
  double   _severity         = 3;
  List<XFile> _images        = [];
  bool     _submitting       = false;

  final _types = [
    'Collision',
    'Rollover',
    'Pedestrian',
    'Other',
  ];

  Future<void> _getCurrentLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _locationCtrl.text = '${pos.latitude}, ${pos.longitude}';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      setState(() => _images.add(file));
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an accident type.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storage = FirebaseStorage.instance;

      // 🔄 Upload images concurrently, always providing non-null metadata
      final uploadFutures = _images.map((xfile) async {
        final file = File(xfile.path);
        final ref = storage
            .ref()
            .child('accident_reports')
            .child(uid)
            .child('${DateTime.now().millisecondsSinceEpoch}_${xfile.name}');
        // ← Pass a default metadata so plugin never sees null
        final metadata = SettableMetadata(contentType: 'image/jpeg');
        await ref.putFile(file, metadata);
        return ref.getDownloadURL();
      }).toList();

      final imageUrls = await Future.wait(uploadFutures);

      // 🔄 Write the report
      await FirebaseFirestore.instance.collection('accident_reports').add({
        'reporterId' : uid,
        'location'   : _locationCtrl.text,
        'timestamp'  : Timestamp.fromDate(_selectedDateTime),
        'type'       : _selectedType,
        'description': _descriptionCtrl.text.trim(),
        'severity'   : _severity.toInt(),
        'imageUrls'  : imageUrls,
        'createdAt'  : FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Accident report submitted successfully!'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      // Log and show any errors
      print('❌ Report submission failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to submit report: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accident Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Location
              TextFormField(
                controller: _locationCtrl,
                decoration: InputDecoration(
                  labelText: 'Location (lat, long)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _getCurrentLocation,
                  ),
                ),
                validator: (v) =>
                    v != null && v.isNotEmpty ? null : 'Enter location',
              ),
              const SizedBox(height: 16),

              // Date & Time
              InkWell(
                onTap: _selectDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date & Time',
                    border: OutlineInputBorder(),
                  ),
                  child:
                      Text('${_selectedDateTime.toLocal()}'.split('.').first),
                ),
              ),
              const SizedBox(height: 16),

              // Accident Type
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Accident Type',
                  border: OutlineInputBorder(),
                ),
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v),
                validator: (v) =>
                    v == null ? 'Select accident type' : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (v) =>
                    v != null && v.isNotEmpty ? null : 'Describe the accident',
              ),
              const SizedBox(height: 16),

              // Photos
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var img in _images)
                    Image.file(
                      File(img.path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _pickImage,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Severity
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Severity'),
                  Slider(
                    value: _severity,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _severity.round().toString(),
                    onChanged: (v) => setState(() => _severity = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _submitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
