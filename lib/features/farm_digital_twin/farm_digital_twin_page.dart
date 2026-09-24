import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/farm_twin_service.dart';
import '../../theme/agri_n_design.dart';

class FarmDigitalTwinPage extends StatefulWidget {
  const FarmDigitalTwinPage({super.key});
  @override State<FarmDigitalTwinPage> createState()=>_FarmDigitalTwinPageState();
}
class _FarmDigitalTwinPageState extends State<FarmDigitalTwinPage>{
  static const green=Color(0xFF2E6B43),dark=Color(0xFF102318),muted=Color(0xFF66736A);
  final location=TextEditingController(); final size=TextEditingController();
  String crop='Rice'; bool loading=false; FarmTwinData? twin; String? error;
  @override void dispose(){location.dispose();size.dispose();super.dispose();}
  Future<void> buildTwin() async {
    if(location.text.trim().isEmpty){setState(()=>error='Enter a farm location first.');return;}
    setState((){loading=true;error=null;twin=null;});
    try {
      final t=await FarmTwinService().build(location:location.text.trim(),crop:crop,farmSizeAcres:double.tryParse(size.text.trim()));
      if(mounted)setState(()=>twin=t);
    } catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext context){
    final wide=MediaQuery.sizeOf(context).width>=900;
    return Scaffold(appBar:AppBar(title:const Text('Farm Digital Twin',style:TextStyle(fontWeight:FontWeight.w800))),body:SafeArea(child:SingleChildScrollView(padding:EdgeInsets.all(wide?48:20),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _hero(wide),const SizedBox(height:18),if(twin==null)_form()else _twin(wide),if(error!=null)...[const SizedBox(height:14),_error()],
    ]))))));
  }
  Widget _hero(bool wide) => Container(
    width: double.infinity,
    color: AgriNDesign.ink,
    padding: const EdgeInsets.fromLTRB(38, 34, 28, 30),
    child: Row(
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
      const Text('AGRI N / DIGITAL TWIN',style:TextStyle(color:Color(0xFF9EB6A5),fontSize:9,letterSpacing:1.9,fontWeight:FontWeight.w800)),
      const SizedBox(height:18),Text('One farm.\nMany signals.',style:Theme.of(context).textTheme.displayMedium?.copyWith(color:Colors.white,fontSize:wide?58:42,height:.9)),
      const SizedBox(height:16),const Text('Turn real observations into a refreshable farm state — without pretending that a point sample is the whole farm.',style:TextStyle(color:Color(0xFFD1DAD3),fontSize:13,height:1.6)),
      const SizedBox(height:20),const Row(children:[_Tag('WEATHER'),SizedBox(width:6),_Tag('SOIL'),SizedBox(width:6),_Tag('SATELLITE'),SizedBox(width:6),_Tag('STATE')]),
        ])),
        if (wide) const SizedBox(width: 30),
        if (wide) const MotionOrb(size: 190, label: 'TWIN'),
      ],
    ),
  ).animate().fadeIn(duration: 600.ms);
  Widget _form()=>Container(padding:const EdgeInsets.all(28),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:AgriNDesign.line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('BUILD OBSERVATION SNAPSHOT',style:TextStyle(color:green,fontSize:9,letterSpacing:1.7,fontWeight:FontWeight.w800)),const SizedBox(height:12),
    TextField(controller:location,decoration:const InputDecoration(labelText:'Farm location',prefixIcon:Icon(Icons.location_on_outlined))),
    const SizedBox(height:12),TextField(controller:size,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Farm size in acres (optional)',prefixIcon:Icon(Icons.square_foot_outlined))),
    const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:crop,decoration:const InputDecoration(labelText:'Crop'),items:const ['Rice','Wheat','Cotton','Sugarcane','Vegetables','Other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>crop=v??crop)),
    const SizedBox(height:18),SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:loading?null:buildTwin,icon:loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.hub_outlined),label:Padding(padding:const EdgeInsets.symmetric(vertical:14),child:Text(loading?'Gathering live evidence...':'Build farm twin')))),
  ]));
  Widget _twin(bool wide)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Expanded(child:Text('CURRENT FARM STATE',style:TextStyle(fontSize:11,letterSpacing:2,fontWeight:FontWeight.w800))),Text('Twin ${twin!.version}',style:const TextStyle(fontSize:10,color:muted))]),
    const SizedBox(height:12),
    GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:wide?3:1,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:2.0,children:[
      _stateCard('WEATHER',twin!.state['weather']?.toString()??'Unavailable',Icons.cloud_outlined),
      _stateCard('SOIL / SURFACE',twin!.state['soil_surface']?.toString()??'Unavailable',Icons.layers_outlined),
      _stateCard('SATELLITE',twin!.state['satellite']?.toString()??'Unavailable',Icons.satellite_alt_outlined),
    ]),
    const SizedBox(height:14),_box('TWIN SEMANTICS',twin!.semantics.entries.map((e)=>'${e.key}: ${e.value}').join('\n')),
    const SizedBox(height:14),_box('NEXT ACTIONS',twin!.actions.map((x)=>'• $x').join('\n')),
    const SizedBox(height:14),_box('LIMITATIONS',twin!.limitations.map((x)=>'• $x').join('\n')),
    const SizedBox(height:14),Text('Generated ${twin!.generatedAt}',style:const TextStyle(fontSize:10,color:muted)),
  ]);
  Widget _stateCard(String title,String value,IconData icon)=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:dark,border:Border.all(color:const Color(0x335B765F))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:const Color(0xFFAEC2B5),size:20),const SizedBox(height:8),Text(title,style:const TextStyle(color:Color(0xFF9EB6A5),fontSize:9,letterSpacing:1.4,fontWeight:FontWeight.w800)),const SizedBox(height:5),Expanded(child:Text(value,style:const TextStyle(color:Colors.white,fontSize:11,height:1.35),maxLines:5,overflow:TextOverflow.ellipsis))]));
  Widget _box(String title,String value)=>Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:AgriNDesign.line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:10,letterSpacing:1.5,fontWeight:FontWeight.w800,color:green)),const SizedBox(height:10),Text(value,style:const TextStyle(fontSize:12,color:dark,height:1.55))]));
  Widget _error()=>Container(width:double.infinity,padding:const EdgeInsets.all(16),color:const Color(0xFFFFF1EC),child:Text(error!,style:const TextStyle(color:dark)));
}
class _Tag extends StatelessWidget{const _Tag(this.text);final String text;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(border:Border.all(color:const Color(0x446F8C76))),child:Text(text,style:const TextStyle(color:Color(0xFFB5C5BA),fontSize:8,letterSpacing:1.2,fontWeight:FontWeight.w700)));}
