import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/disease_service.dart';

class CropDoctorPage extends StatefulWidget {
  const CropDoctorPage({super.key});
  @override State<CropDoctorPage> createState() => _CropDoctorPageState();
}

class _CropDoctorPageState extends State<CropDoctorPage> {
  static const green = Color(0xFF2E6B43);
  static const dark = Color(0xFF102318);
  static const muted = Color(0xFF66736A);
  final picker = ImagePicker();
  final crop = TextEditingController(text: 'Rice');
  final location = TextEditingController();
  XFile? image;
  Uint8List? bytes;
  DiseaseAnalysis? result;
  String? error;
  bool busy = false;

  @override
  void dispose() { crop.dispose(); location.dispose(); super.dispose(); }

  Future<void> choose(ImageSource source) async {
    final x = await picker.pickImage(source: source, imageQuality: 88, maxWidth: 1600, maxHeight: 1600);
    if (x == null) return;
    setState(() { image = x; result = null; error = null; });
    bytes = await x.readAsBytes();
    if (mounted) setState(() {});
  }

  Future<void> analyze() async {
    if (bytes == null) { setState(() => error = 'Please add a clear crop or leaf photo.'); return; }
    setState(() { busy = true; error = null; result = null; });
    try {
      result = await DiseaseService().analyze(
        imageBytes: bytes!,
        mimeType: image?.mimeType ?? 'image/jpeg',
        crop: crop.text.trim(),
        location: location.text.trim(),
      );
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(title: const Text('Crop Doctor', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(child: SingleChildScrollView(
        padding: EdgeInsets.all(wide ? 48 : 20),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _header(), const SizedBox(height: 20),
            wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _input()), const SizedBox(width: 20), Expanded(child: _photo())
            ]) : Column(children: [_input(), const SizedBox(height: 20), _photo()]),
            if (result != null) ...[const SizedBox(height: 20), _result()],
            if (error != null) ...[const SizedBox(height: 16), _error()],
          ]),
        )),
      )),
    );
  }

  Widget _header() => Container(
    width: double.infinity, padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF173B26), Color(0xFF3F7D4C)]),
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.local_florist_rounded, color: Colors.white, size: 36),
      SizedBox(height: 14),
      Text('Crop Doctor', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
      SizedBox(height: 8),
      Text('Upload a crop or leaf photo for an evidence-aware AI assessment.',
        style: TextStyle(color: Color(0xCCDDE9DF), height: 1.5)),
    ]),
  );

  Widget _input() => _card('Crop details', Column(children: [
    TextField(controller: crop, decoration: _dec('Crop name', Icons.grass_rounded)),
    const SizedBox(height: 14),
    TextField(controller: location, decoration: _dec('Location (optional)', Icons.location_on_outlined)),
    const SizedBox(height: 18),
    Row(children: [
      Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => choose(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery'))),
      const SizedBox(width: 10),
      Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => choose(ImageSource.camera),
        icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera'))),
    ]),
    const SizedBox(height: 14),
    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: busy ? null : analyze,
      icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded),
      label: Padding(padding: const EdgeInsets.symmetric(vertical: 15),
        child: Text(busy ? 'Analyzing image...' : 'Analyze crop')),
      style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
    )),
  ]));

  Widget _photo() => _card('Photo', bytes == null
    ? const SizedBox(height: 250, child: Center(child: Text('Add a clear leaf or crop photo.', style: TextStyle(color: muted))))
    : ClipRRect(borderRadius: BorderRadius.circular(18),
        child: Image.memory(bytes!, height: 280, width: double.infinity, fit: BoxFit.cover)));

  Widget _result() => Container(
    width: double.infinity, padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(24)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.health_and_safety_outlined, color: Colors.white),
        SizedBox(width: 10),
        Text('AI assessment', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 14),
      Text(result!.assessment, style: const TextStyle(color: Color(0xFFD4DDD7), height: 1.55)),
      if (result!.possibleIssues.isNotEmpty) ...[
        const SizedBox(height: 18), const Text('Possible issues', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8), ...result!.possibleIssues.map(_bullet),
      ],
      if (result!.observations.isNotEmpty) ...[
        const SizedBox(height: 16), const Text('Visual observations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8), ...result!.observations.map(_bullet),
      ],
      if (result!.actions.isNotEmpty) ...[
        const SizedBox(height: 16), const Text('Recommended next checks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...result!.actions.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(a.title + ': ' + a.reason + ' (Priority: ' + a.priority + ')',
            style: const TextStyle(color: Color(0xFFD4DDD7), fontSize: 12, height: 1.4)),
        )),
      ],
      if (result!.limitations.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Limits: ' + result!.limitations.join(' • '),
          style: const TextStyle(color: Color(0xFF9FB0A4), fontSize: 10, height: 1.4)),
      ],
      const SizedBox(height: 12),
      Text(result!.source + ' • ' + result!.model,
        style: const TextStyle(color: Color(0xFF9FB0A4), fontSize: 10)),
    ]),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(color: Color(0xFF9FB0A4))),
      Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFD4DDD7), fontSize: 12, height: 1.4))),
    ]),
  );

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, color: green), filled: true,
    fillColor: const Color(0xFFF7F9F5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
  );

  Widget _card(String title, Widget child) => Container(
    width: double.infinity, padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE5EAE5))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 18), child,
    ]),
  );

  Widget _error() => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFFFFF3F0), borderRadius: BorderRadius.circular(18)),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Colors.deepOrange), const SizedBox(width: 10),
      Expanded(child: Text(error!, style: const TextStyle(color: dark))),
    ]),
  );
}
