import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FarmIntelligencePage extends StatefulWidget {
  const FarmIntelligencePage({super.key});
  @override
  State<FarmIntelligencePage> createState() => _FarmIntelligencePageState();
}

class _FarmIntelligencePageState extends State<FarmIntelligencePage> {
  static const green = Color(0xFF2E6B43);
  static const dark = Color(0xFF102318);
  final location = TextEditingController();
  final size = TextEditingController();
  String crop = 'Rice';
  DateTime? date;

  @override
  void dispose() { location.dispose(); size.dispose(); super.dispose(); }

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime.now(),
      initialDate: date ?? DateTime.now(),
    );
    if (d != null) setState(() => date = d);
  }

  void continueFarm() {
    if (location.text.trim().isEmpty || size.text.trim().isEmpty || date == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete your farm details first.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Farm profile saved. Intelligence analysis comes next.')));
  }

  InputDecoration decoration(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, color: green), filled: true,
    fillColor: const Color(0xFFF7F9F5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: green, width: 1.4)),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(title: const Text('Farm Intelligence', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(child: SingleChildScrollView(
        padding: EdgeInsets.all(wide ? 48 : 20),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF173B26), Color(0xFF3F7D4C)]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 34),
                SizedBox(height: 14),
                Text('Let’s understand your farm', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('Tell AgriN where and what you grow. This becomes the context for localized weather, soil and crop intelligence.',
                  style: TextStyle(color: Color(0xCCDDE9DF), height: 1.5)),
              ]),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: .06, end: 0),
            const SizedBox(height: 22),
            wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: formCard()), const SizedBox(width: 20), Expanded(child: previewCard()),
            ]) : Column(children: [formCard(), const SizedBox(height: 20), previewCard()]),
          ]),
        )),
      )),
    );
  }

  Widget formCard() => card('Farm profile', Column(children: [
    TextField(controller: location, decoration: decoration('Village / district / location', Icons.location_on_outlined)),
    const SizedBox(height: 15),
    DropdownButtonFormField<String>(
      value: crop, decoration: decoration('Primary crop', Icons.grass_rounded),
      items: const ['Rice','Wheat','Cotton','Sugarcane','Tomato','Other'].map((x) => DropdownMenuItem(value:x, child:Text(x))).toList(),
      onChanged: (x) => setState(() => crop = x ?? crop),
    ),
    const SizedBox(height: 15),
    TextField(controller: size, keyboardType: const TextInputType.numberWithOptions(decimal:true),
      decoration: decoration('Farm size (acres)', Icons.straighten_rounded)),
    const SizedBox(height: 15),
    InkWell(
      onTap: pickDate, child: InputDecorator(
        decoration: decoration('Sowing date', Icons.calendar_month_outlined),
        child: Text(date == null ? 'Select sowing date' : date!.day.toString().padLeft(2,'0') + '/' + date!.month.toString().padLeft(2,'0') + '/' + date!.year.toString()),
      ),
    ),
    const SizedBox(height: 20),
    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: continueFarm, icon: const Icon(Icons.arrow_forward_rounded),
      label: const Padding(padding: EdgeInsets.symmetric(vertical:15), child: Text('Continue to farm analysis')),
      style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
    )),
  ]));

  Widget previewCard() => card('What AgriN will analyze', const Column(children: [
    ListTile(leading: Icon(Icons.cloud_outlined, color: green), title: Text('Weather'), subtitle: Text('Forecast and climate-risk signals')),
    ListTile(leading: Icon(Icons.water_drop_outlined, color: green), title: Text('Soil'), subtitle: Text('Moisture and soil-health indicators')),
    ListTile(leading: Icon(Icons.satellite_alt_outlined, color: green), title: Text('Satellite'), subtitle: Text('Vegetation and water-stress signals')),
    ListTile(leading: Icon(Icons.auto_awesome_rounded, color: green), title: Text('AI Advisory'), subtitle: Text('Localized actions explained simply')),
  ]));

  Widget card(String title, Widget child) => Container(
    width: double.infinity, padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5EAE5))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize:19, fontWeight:FontWeight.w800, color:dark)),
      const SizedBox(height:18), child,
    ]),
  );
}
