import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/weather_service.dart';
import '../../services/soil_service.dart';
import '../../services/satellite_service.dart';
import '../../services/advisory_service.dart';

class AiAdvisoryPage extends StatefulWidget {
  const AiAdvisoryPage({super.key});
  @override State<AiAdvisoryPage> createState() => _AiAdvisoryPageState();
}

class _AiAdvisoryPageState extends State<AiAdvisoryPage> {
  static const green=Color(0xFF2E6B43), dark=Color(0xFF102318), muted=Color(0xFF66736A);
  final location=TextEditingController(), acres=TextEditingController();
  String crop='Rice'; DateTime? sowingDate; bool loading=false;
  AdvisoryData? advisory; String? error;
  @override void dispose(){location.dispose();acres.dispose();super.dispose();}

  Future<void> pickDate() async {
    final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime.now(),initialDate:sowingDate??DateTime.now());
    if(d!=null)setState(()=>sowingDate=d);
  }

  Future<void> generate() async {
    final size=double.tryParse(acres.text.trim());
    if(location.text.trim().isEmpty || size==null || sowingDate==null){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter location, farm size and sowing date.'))); return;
    }
    setState(() { loading=true; advisory=null; error=null; });
    try {
      final w=await WeatherService().fetch(location.text.trim());
      final s=await SoilService().fetch(latitude:w.latitude,longitude:w.longitude);
      SatelliteData? sat;
      try { sat=await SatelliteService().fetch(latitude:w.latitude,longitude:w.longitude); } catch (_) {}
      final a=await AdvisoryService().fetch(location:location.text.trim(),crop:crop,farmSizeAcres:size,sowingDate:sowingDate!,weather:w,soil:s,satellite:sat);
      if(mounted)setState(()=>advisory=a);
    } catch(e) { if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ','')); }
    if(mounted)setState(()=>loading=false);
  }

  InputDecoration dec(String label,IconData icon)=>InputDecoration(labelText:label,prefixIcon:Icon(icon,color:green),filled:true,fillColor:const Color(0xFFF7F9F5),border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:green,width:1.4)));

  @override Widget build(BuildContext context) {
    final wide=MediaQuery.sizeOf(context).width>=900;
    return Scaffold(appBar:AppBar(title:const Text('AI Agro-Advisory',style:TextStyle(fontWeight:FontWeight.w800))),body:SafeArea(child:SingleChildScrollView(padding:EdgeInsets.all(wide?48:20),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1050),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_hero(),const SizedBox(height:20),_form(wide),if(error!=null)...[const SizedBox(height:16),_error()],if(advisory!=null)...[const SizedBox(height:20),_result(advisory!)]]))))));
  }

  Widget _hero() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1D13), Color(0xFF2E6B43)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Color(0x22102D1B), blurRadius: 28, offset: Offset(0, 12)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(.94, .94), end: const Offset(1.06, 1.06), duration: 1400.ms)
                .shimmer(duration: 1800.ms, color: Colors.white.withValues(alpha: .16)),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Agro-Advisory',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  SizedBox(height: 7),
                  Text('Generate evidence-grounded actions from your real farm signals.',
                      style: TextStyle(color: Color(0xCCDDE9DF), height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: .08, end: 0, curve: Curves.easeOutCubic);

  Widget _form(bool wide) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5EAE5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Farm context', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: dark)),
        const SizedBox(height: 18),
        TextField(controller: location, decoration: dec('Village / district / location', Icons.location_on_outlined)).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: -.03, end: 0),
        const SizedBox(height: 14),
        if (wide) Row(children: [Expanded(child: _crop().animate().fadeIn(delay: 180.ms, duration: 400.ms).slideY(begin: .04, end: 0)), const SizedBox(width: 14), Expanded(child: _acres().animate().fadeIn(delay: 240.ms, duration: 400.ms).slideY(begin: .04, end: 0))])
        else Column(children: [_crop().animate().fadeIn(delay: 180.ms, duration: 400.ms).slideY(begin: .04, end: 0), const SizedBox(height: 14), _acres().animate().fadeIn(delay: 240.ms, duration: 400.ms).slideY(begin: .04, end: 0)]),
        const SizedBox(height: 14),
        InkWell(
          onTap: pickDate,
          child: InputDecorator(
            decoration: dec('Sowing date', Icons.calendar_month_outlined),
            child: Text(sowingDate == null ? 'Select sowing date' : sowingDate!.day.toString().padLeft(2, '0') + '/' + sowingDate!.month.toString().padLeft(2, '0') + '/' + sowingDate!.year.toString()),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: loading ? null : generate,
            icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded),
            label: Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Text(loading ? 'Reading live farm signals...' : 'Generate AI advisory')),
            style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
      ],),
    ).animate().fadeIn(duration: 550.ms).slideY(begin: .05, end: 0);
  }
  Widget _crop() {
    return DropdownButtonFormField<String>(
      value: crop,
      decoration: dec('Crop', Icons.grass_rounded),
      items: const ['Rice','Wheat','Cotton','Sugarcane','Tomato','Other'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
      onChanged: (x) => setState(() => crop = x ?? crop),
    );
  }

  Widget _acres() {
    return TextField(
      controller: acres,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: dec('Farm size (acres)', Icons.straighten_rounded),
    );
  }
  Widget _result(AdvisoryData a) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: dark,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x33102D1B), blurRadius: 30, offset: Offset(0, 14)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Generated advisory',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 16),
            Text(a.summary, style: const TextStyle(color: Color(0xFFD4DDD7), height: 1.55))
                .animate().fadeIn(delay: 120.ms, duration: 500.ms).slideY(begin: .04, end: 0),
            if (a.observations.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('Observed signals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...a.observations.asMap().entries.map((entry) =>
                Text('• ' + entry.value, style: const TextStyle(color: Color(0xFFD4DDD7), fontSize: 12, height: 1.5))
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 180 + entry.key * 45), duration: 350.ms)
                    .slideX(begin: .02, end: 0)),
            ],
            if (a.actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              ...a.actions.asMap().entries.map((entry) {
                final x = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C3325),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0x223F7A50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(x.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text(x.reason, style: const TextStyle(color: Color(0xFFD4DDD7), fontSize: 12, height: 1.45)),
                      const SizedBox(height: 6),
                      Text('Priority: ' + x.priority + ' • Confidence: ' + x.confidence,
                          style: const TextStyle(color: Color(0xFF9FB0A4), fontSize: 10)),
                    ],
                  ),
                ).animate()
                    .fadeIn(delay: Duration(milliseconds: 220 + entry.key * 90), duration: 450.ms)
                    .slideY(begin: .06, end: 0, curve: Curves.easeOutCubic);
              }),
            ],
            if (a.watchItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Watch next', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              ...a.watchItems.asMap().entries.map((entry) =>
                Text('• ' + entry.value, style: const TextStyle(color: Color(0xFFD4DDD7), fontSize: 12, height: 1.5))
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 320 + entry.key * 50), duration: 350.ms)),
            ],
            if (a.dataLimits.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Data limits: ' + a.dataLimits.join(' • '),
                  style: const TextStyle(color: Color(0xFF9FB0A4), fontSize: 10, height: 1.4))
                  .animate().fadeIn(delay: 450.ms, duration: 400.ms),
            ],
            const SizedBox(height: 14),
            Text(a.source + ' • ' + a.model, style: const TextStyle(color: Color(0xFF9FB0A4), fontSize: 10))
                .animate().fadeIn(delay: 500.ms, duration: 400.ms),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: .06, end: 0, curve: Curves.easeOutCubic);

  Widget _error()=>Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFFFFF3F0),borderRadius:BorderRadius.circular(16)),child:Row(children:[const Icon(Icons.error_outline,color:Colors.deepOrange),const SizedBox(width:10),Expanded(child:Text(error??'Unable to generate advisory.',style:const TextStyle(color:dark)))]));
}