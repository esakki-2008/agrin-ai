import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/weather_service.dart';
import '../../services/soil_service.dart';
import '../../services/regenerative_service.dart';

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

  Widget _hero()=>Container(width:double.infinity,padding:const EdgeInsets.all(28),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF173B26),Color(0xFF4D8256)]),borderRadius:BorderRadius.circular(28)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(Icons.eco_rounded,color:Colors.white,size:34),SizedBox(height:14),
    Text('Build a regenerative plan',style:TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w800)),
    SizedBox(height:8),Text('Use live weather and model-derived soil context to organize practical soil, water and biodiversity actions.',style:TextStyle(color:Color(0xCCDDE9DF),height:1.5)),
  ])).animate().fadeIn(duration:600.ms).slideY(begin:.06,end:0);

  Widget _form()=>_card('Farm context',Column(children:[
    TextField(controller:location,decoration:decoration('Village / district / location',Icons.location_on_outlined)),
    const SizedBox(height:15),
    DropdownButtonFormField<String>(value:crop,decoration:decoration('Primary crop',Icons.grass_rounded),items:const ['Rice','Wheat','Cotton','Sugarcane','Tomato','Other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>crop=x??crop)),
    const SizedBox(height:20),
    SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:loading?null:buildPlan,icon:loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.eco_rounded),label:Padding(padding:const EdgeInsets.symmetric(vertical:15),child:Text(loading?'Building live plan...':'Build regenerative plan')),style:ElevatedButton.styleFrom(backgroundColor:green,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))))),
  ])).animate().fadeIn(duration:550.ms).slideX(begin:-.04,end:0);

  Widget _results(bool wide){
    final p=plan!;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Regenerative intelligence',style:TextStyle(fontSize:wide?32:27,fontWeight:FontWeight.w800,color:dark)),
      const SizedBox(height:6),Text(p.location+' • '+p.crop,style:const TextStyle(color:muted)),
      const SizedBox(height:18),if(weather!=null&&soil!=null)_liveContext(wide),
      const SizedBox(height:20),_sectionTitle('Recommended practices'),const SizedBox(height:10),
      ...p.practices.asMap().entries.map((e)=>_practice(e.value,e.key)),
      if(p.evidence.isNotEmpty)...[const SizedBox(height:18),_sectionTitle('Evidence used'),const SizedBox(height:10),...p.evidence.map(_evidence)],
      const SizedBox(height:18),_sectionTitle('Plan limitations'),const SizedBox(height:10),_darkList(p.limitations),
      const SizedBox(height:16),Text(p.source,style:const TextStyle(fontSize:10,color:muted)),
    ]).animate().fadeIn(duration:650.ms).slideY(begin:.05,end:0);
  }

  Widget _liveContext(bool wide)=>GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:wide?4:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.55,children:[
    _metric(weather!.temperature.toStringAsFixed(1)+'°C','Live temperature'),
    _metric(weather!.humidity.toStringAsFixed(0)+'%','Live humidity'),
    _metric(weather!.rainProbability.toString()+'%','Rain probability'),
    _metric(soil!.organicCarbon.toStringAsFixed(1),'Soil organic C g/kg'),
  ]);

  Widget _metric(String value,String label)=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:const Color(0xFFE5EAE5))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:dark)),const SizedBox(height:4),Text(label,style:const TextStyle(fontSize:11,color:muted))]));

  Widget _practice(RegenerativePractice item,int index)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFFE5EAE5))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFEAF4EC),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.eco_outlined,color:green)),
    const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(item.title,style:const TextStyle(fontWeight:FontWeight.w800,color:dark)),const SizedBox(height:5),
      Text(item.reason,style:const TextStyle(color:muted,fontSize:12,height:1.45)),const SizedBox(height:7),
      Text(item.priority.toUpperCase()+' • '+item.basis,style:const TextStyle(color:green,fontSize:10,fontWeight:FontWeight.w700)),
    ])),
  ])).animate(delay:(70*index).ms).fadeIn(duration:350.ms).slideY(begin:.04,end:0);

  Widget _evidence(RegenerativeEvidence item)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFFF7F9F5),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(item.signal+': '+item.value,style:const TextStyle(fontWeight:FontWeight.w700,color:dark)),const SizedBox(height:4),
    Text(item.interpretation,style:const TextStyle(color:muted,fontSize:12,height:1.4)),const SizedBox(height:4),
    Text('Source: '+item.source,style:const TextStyle(color:muted,fontSize:10)),
  ]));

  Widget _darkList(List<String> items)=>Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:dark,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:items.map((x)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Text('• '+x,style:const TextStyle(color:Color(0xFFD4DDD7),fontSize:11,height:1.4)))).toList()));
  Widget _sectionTitle(String text)=>Text(text,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:dark));
  Widget _error()=>Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFFFF3F0),borderRadius:BorderRadius.circular(18)),child:Row(children:[const Icon(Icons.error_outline,color:Colors.deepOrange),const SizedBox(width:10),Expanded(child:Text(error!,style:const TextStyle(color:dark)))]));
  Widget _card(String title,Widget child)=>Container(width:double.infinity,padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24),border:Border.all(color:const Color(0xFFE5EAE5))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:dark)),const SizedBox(height:18),child]));
}
