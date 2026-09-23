import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/weather_service.dart';
import '../../services/soil_service.dart';
import '../../services/satellite_service.dart';
import '../../services/advisory_service.dart';
import '../../theme/agri_n_design.dart';
import '../../l10n/language_picker.dart';
import '../../l10n/language_controller.dart';

class AiAdvisoryPage extends StatefulWidget {
  const AiAdvisoryPage({super.key});
  @override State<AiAdvisoryPage> createState() => _AiAdvisoryPageState();
}

class _AiAdvisoryPageState extends State<AiAdvisoryPage> {
  static const green=Color(0xFF2E6B43), dark=Color(0xFF102318);
  final location=TextEditingController(), acres=TextEditingController();
  String crop='Rice'; DateTime? sowingDate; bool loading=false;
  AdvisoryData? advisory; String? error;
  String responseLanguage='English';
  @override void initState(){super.initState(); responseLanguage=languageController.language.aiName;}
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
      final a=await AdvisoryService().fetch(location:location.text.trim(),crop:crop,farmSizeAcres:size,sowingDate:sowingDate!,weather:w,soil:s,satellite:sat,responseLanguage:responseLanguage);
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
    color: AgriNDesign.ink,
    padding: const EdgeInsets.fromLTRB(36, 36, 24, 36),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('DECISION ENGINE / 03', style: TextStyle(color: Color(0xFF9EB6A5), fontSize: 9, letterSpacing: 1.9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Text('Advice with\\nevidence behind it.', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white, fontSize: 52, height: .9)),
        const SizedBox(height: 18),
        const Text('AgriN gathers the farm signals first, then turns the available evidence into practical actions — with data limits kept visible.', style: TextStyle(color: Color(0xCCDDE9DF), fontSize: 13, height: 1.6)),
      ])),
      const SizedBox(width: 24),
      const SizedBox(width: 210, height: 210, child: _DecisionOrb()),
    ]),
  ).animate().fadeIn(duration: 600.ms).slideY(begin: .05, end: 0);

  Widget _form(bool wide) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.zero, border: Border.all(color: const Color(0xFFE5EAE5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Farm context', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: dark))),
          LanguagePicker(compact:true,onChanged:(language){setState(() => responseLanguage=language.aiName);}),
        ]),
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
            child: Text(sowingDate == null ? 'Select sowing date' : '${sowingDate!.day.toString().padLeft(2, '0')}/${sowingDate!.month.toString().padLeft(2, '0')}/${sowingDate!.year}'),
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
                Text('• ${entry.value}', style: const TextStyle(color: Color(0xFFD4DDD7), fontSize: 12, height: 1.5))
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
                      Text('Priority: ${x.priority} • Confidence: ${x.confidence}',
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
                Text('• ${entry.value}', style: const TextStyle(color: Color(0xFFD4DDD7), fontSize: 12, height: 1.5))
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 320 + entry.key * 50), duration: 350.ms)),
            ],
            if (a.dataLimits.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Data limits: ${a.dataLimits.join(' • ')}',
                  style: const TextStyle(color: Color(0xFF9FB0A4), fontSize: 10, height: 1.4))
                  .animate().fadeIn(delay: 450.ms, duration: 400.ms),
            ],
            const SizedBox(height: 14),
            Text('${a.source} • ${a.model}', style: const TextStyle(color: Color(0xFF9FB0A4), fontSize: 10))
                .animate().fadeIn(delay: 500.ms, duration: 400.ms),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: .06, end: 0, curve: Curves.easeOutCubic);

  Widget _error()=>Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFFFFF3F0),borderRadius:BorderRadius.circular(16)),child:Row(children:[const Icon(Icons.error_outline,color:Colors.deepOrange),const SizedBox(width:10),Expanded(child:Text(error??'Unable to generate advisory.',style:const TextStyle(color:dark)))]));
}
class _DecisionOrb extends StatelessWidget {
  const _DecisionOrb();
  @override Widget build(BuildContext context)=>Stack(alignment:Alignment.center,children:[
    Container(width:205,height:205,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0x445E7865)))),
    Container(width:145,height:145,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0x6685A18B)))),
    Container(width:70,height:70,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0x332E6B43),border:Border.all(color:const Color(0x889AB6A2))),child:const Icon(Icons.auto_awesome_outlined,color:Color(0xFFD8E3DB),size:28)),
    const Positioned(top:4,left:22,child:_DecisionTag('WEATHER')),
    const Positioned(right:0,bottom:35,child:_DecisionTag('SOIL')),
    const Positioned(left:4,bottom:12,child:_DecisionTag('SATELLITE')),
  ]);
}
class _DecisionTag extends StatelessWidget {
  const _DecisionTag(this.text); final String text;
  @override Widget build(BuildContext context)=>Container(color:const Color(0xDD151914),padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),child:Text(text,style:const TextStyle(color:Color(0xFFB5C2B9),fontSize:7,letterSpacing:1.1,fontWeight:FontWeight.w700)));
}
