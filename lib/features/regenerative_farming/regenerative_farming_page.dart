import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/weather_service.dart';
import '../../services/soil_service.dart';
import '../../services/regenerative_service.dart';
import '../../theme/agri_n_design.dart';

class RegenerativeFarmingPage extends StatefulWidget {
  const RegenerativeFarmingPage({super.key});
  @override State<RegenerativeFarmingPage> createState()=>_RegenerativeFarmingPageState();
}
class _RegenerativeFarmingPageState extends State<RegenerativeFarmingPage> {
  static const green=Color(0xFF2E6B43), dark=Color(0xFF102318), muted=Color(0xFF66736A);
  final location=TextEditingController();
  String crop='Rice'; bool loading=false; String? error;
  WeatherData? weather; SoilData? soil; RegenerativePlan? plan;
  @override void dispose(){location.dispose();super.dispose();}

  Future<void> buildPlan() async {
    if(location.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a village, district, or location first.')));return;}
    setState((){loading=true;error=null;weather=null;soil=null;plan=null;});
    try {
      final w=await WeatherService().fetch(location.text.trim());
      final s=await SoilService().fetch(latitude:w.latitude,longitude:w.longitude);
      final p=await RegenerativeService().fetch(location:w.location,crop:crop,temperature:w.temperature,humidity:w.humidity,rainProbability:w.rainProbability,ph:s.ph,organicCarbon:s.organicCarbon,nitrogen:s.nitrogen,clay:s.clay,soilSource:s.source);
      if(!mounted)return;
      setState((){weather=w;soil=s;plan=p;});
    } catch(e) { if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ','')); }
    finally { if(mounted)setState(()=>loading=false); }
  }

  InputDecoration decoration(String label,IconData icon)=>InputDecoration(labelText:label,prefixIcon:Icon(icon,color:green),filled:true,fillColor:const Color(0xFFF7F9F5),border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:green,width:1.4)));

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Regenerative Farming',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 48 : 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _hero(),
                  const SizedBox(height: 14),
                  _landLayers(),
                  const SizedBox(height: 20),
                  if (plan == null) _form() else _results(wide),
                  if (error != null) ...[
                    const SizedBox(height: 18),
                    _error(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero()=>Container(width:double.infinity,color:AgriNDesign.ink,padding:const EdgeInsets.fromLTRB(34,34,24,34),child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('REGENERATIVE FARM INTELLIGENCE',style:TextStyle(color:Color(0xFF9EB6A5),fontSize:9,letterSpacing:1.9,fontWeight:FontWeight.w800)),
      const SizedBox(height:18),
      Text('Build a plan\nfrom the land.',style:Theme.of(context).textTheme.displayMedium?.copyWith(color:Colors.white,fontSize:wideFont(context)?52:40,height:.92)),
      const SizedBox(height:17),
      const Text('Use live weather and model-derived soil context to organize practical soil, water, cover and biodiversity actions — with evidence and limitations visible.',style:TextStyle(color:Color(0xCCDDE9DF),fontSize:13,height:1.6)),
    ])),
    const SizedBox(width:20),
    SizedBox(width:210,height:210,child:Stack(alignment:Alignment.center,children:[
      Container(width:190,height:190,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0x445E7865)))),
      Container(width:130,height:130,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0x6685A18B)))),
      const Icon(Icons.eco_outlined,color:Color(0xFFB7C8BC),size:42),
      const Positioned(top:12,right:8,child:_SignalTag('SOIL')),
      const Positioned(bottom:18,left:4,child:_SignalTag('WATER')),
      const Positioned(bottom:6,right:12,child:_SignalTag('COVER')),
    ])),
  ])).animate().fadeIn(duration:600.ms).slideY(begin:.05,end:0);

  bool wideFont(BuildContext c)=>MediaQuery.sizeOf(c).width>=900;

  Widget _landLayers() {
    final layers = [
      ('COVER', 'Protect surface', Icons.grass_outlined),
      ('SOIL', 'Build organic matter', Icons.layers_outlined),
      ('WATER', 'Retain and observe', Icons.water_drop_outlined),
      ('BIODIVERSITY', 'Increase resilience', Icons.eco_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LAND SYSTEM', style: TextStyle(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w800, color: AgriNDesign.muted)),
        const SizedBox(height: 10),
        ...layers.asMap().entries.map((e) {
          final item = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: e.key.isEven ? Colors.white : AgriNDesign.paper2,
              border: Border.all(color: AgriNDesign.line),
            ),
            child: Row(
              children: [
                Icon(item.$3, size: 18, color: AgriNDesign.green),
                const SizedBox(width: 12),
                Text(item.$1, style: const TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(item.$2, style: const TextStyle(fontSize: 11, color: AgriNDesign.muted)),
              ],
            ),
          ).animate(delay: (70 * e.key).ms).fadeIn(duration: 350.ms).slideX(begin: .03, end: 0);
        }),
      ],
    );
  }

  Widget _form()=>_card('Farm context',Column(children:[
    TextField(controller:location,decoration:decoration('Village / district / location',Icons.location_on_outlined)).animate().fadeIn(delay:100.ms,duration:350.ms),
    const SizedBox(height:15),
    DropdownButtonFormField<String>(value:crop,decoration:decoration('Primary crop',Icons.grass_rounded),items:const ['Rice','Wheat','Cotton','Sugarcane','Tomato','Other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>crop=x??crop)),
    const SizedBox(height:20),
    SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:loading?null:buildPlan,icon:loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.eco_rounded),label:Padding(padding:const EdgeInsets.symmetric(vertical:15),child:Text(loading?'Building live plan...':'Build regenerative plan')),style:ElevatedButton.styleFrom(backgroundColor:green,foregroundColor:Colors.white,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.zero)))),
  ])).animate().fadeIn(duration:550.ms).slideX(begin:-.04,end:0);

  Widget _results(bool wide){
    final p=plan!;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('LAND SYSTEM / DECISION PLAN',style:TextStyle(fontSize:9,letterSpacing:1.8,fontWeight:FontWeight.w800,color:green)),
      const SizedBox(height:8),
      Text('Regenerative intelligence',style:TextStyle(fontSize:wide?38:29,fontWeight:FontWeight.w800,color:dark)),
      const SizedBox(height:6),Text('${p.location} • ${p.crop}',style:const TextStyle(color:muted)),
      const SizedBox(height:18),if(weather!=null&&soil!=null)_liveContext(wide),
      const SizedBox(height:20),_sectionTitle('Recommended practices'),const SizedBox(height:10),
      ...p.practices.asMap().entries.map((e)=>_practice(e.value,e.key)),
      if(p.evidence.isNotEmpty)...[const SizedBox(height:18),_sectionTitle('Evidence used'),const SizedBox(height:10),...p.evidence.map(_evidence)],
      const SizedBox(height:18),_sectionTitle('Plan limitations'),const SizedBox(height:10),_darkList(p.limitations),
      const SizedBox(height:16),Text(p.source,style:const TextStyle(fontSize:10,color:muted)),
    ]).animate().fadeIn(duration:650.ms).slideY(begin:.05,end:0);
  }

  Widget _liveContext(bool wide)=>GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:wide?4:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.55,children:[
    _metric('${weather!.temperature.toStringAsFixed(1)}°C','Live temperature'),
    _metric('${weather!.humidity.toStringAsFixed(0)}%','Live humidity'),
    _metric('${weather!.rainProbability}%','Rain probability'),
    _metric(soil!.organicCarbon.toStringAsFixed(1),'Soil organic C g/kg'),
  ]);

  Widget _metric(String value,String label)=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(2),border:Border.all(color:AgriNDesign.line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:dark)),const SizedBox(height:4),Text(label,style:const TextStyle(fontSize:11,color:muted))])).animate().fadeIn(duration:350.ms).scale(begin:const Offset(.96,.96),end:const Offset(1,1));

  Widget _practice(RegenerativePractice item,int index)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.zero,border:Border.all(color:const Color(0xFFE5EAE5))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Container(width:42,height:42,decoration:const BoxDecoration(color:Color(0xFFEAF4EC),borderRadius:BorderRadius.zero),child:const Icon(Icons.eco_outlined,color:green)),
    const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(item.title,style:const TextStyle(fontWeight:FontWeight.w800,color:dark)),const SizedBox(height:5),
      Text(item.reason,style:const TextStyle(color:muted,fontSize:12,height:1.45)),const SizedBox(height:7),
      Text('${item.priority.toUpperCase()} • ${item.basis}',style:const TextStyle(color:green,fontSize:10,fontWeight:FontWeight.w700)),
    ])),
  ])).animate(delay:(70*index).ms).fadeIn(duration:350.ms).slideY(begin:.04,end:0);

  Widget _evidence(RegenerativeEvidence item)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),decoration:const BoxDecoration(color:Color(0xFFF7F9F5),borderRadius:BorderRadius.zero),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('${item.signal}: ${item.value}',style:const TextStyle(fontWeight:FontWeight.w700,color:dark)),const SizedBox(height:4),
    Text(item.interpretation,style:const TextStyle(color:muted,fontSize:12,height:1.4)),const SizedBox(height:4),
    Text('Source: ${item.source}',style:const TextStyle(color:muted,fontSize:10)),
  ]));

  Widget _darkList(List<String> items)=>Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:dark,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:items.map((x)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Text('• $x',style:const TextStyle(color:Color(0xFFD4DDD7),fontSize:11,height:1.4)))).toList()));
  Widget _sectionTitle(String text)=>Text(text,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:dark));
  Widget _error()=>Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFFFF3F0),borderRadius:BorderRadius.circular(18)),child:Row(children:[const Icon(Icons.error_outline,color:Colors.deepOrange),const SizedBox(width:10),Expanded(child:Text(error!,style:const TextStyle(color:dark)))]));
  Widget _card(String title,Widget child)=>Container(width:double.infinity,padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.zero,border:Border.all(color:const Color(0xFFE5EAE5))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:dark)),const SizedBox(height:18),child]));
}

class _SignalTag extends StatelessWidget {
  const _SignalTag(this.text);
  final String text;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),color:const Color(0xDD151914),child:Text(text,style:const TextStyle(color:Color(0xFFB5C2B9),fontSize:7,letterSpacing:1.2,fontWeight:FontWeight.w700)));
}
