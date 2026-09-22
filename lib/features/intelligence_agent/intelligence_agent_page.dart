import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/agent_service.dart';
import '../../theme/agri_n_design.dart';

class IntelligenceAgentPage extends StatefulWidget {
  const IntelligenceAgentPage({super.key});
  @override State<IntelligenceAgentPage> createState()=>_IntelligenceAgentPageState();
}

class _IntelligenceAgentPageState extends State<IntelligenceAgentPage> {
  static const green=Color(0xFF2E6B43), ink=Color(0xFF10130F), muted=Color(0xFF687168);
  final location=TextEditingController(), acres=TextEditingController();
  String crop='Rice'; int days=30; bool loading=false; AgentData? data; String? error;

  @override void dispose(){location.dispose();acres.dispose();super.dispose();}

  Future<void> runAgent() async {
    final loc=location.text.trim();
    final size=acres.text.trim().isEmpty?null:double.tryParse(acres.text.trim());
    if(loc.isEmpty){setState(()=>error='Enter a farm location first.');return;}
    if(acres.text.trim().isNotEmpty&&size==null){setState(()=>error='Farm size must be a valid number.');return;}
    setState((){loading=true;data=null;error=null;});
    try {
      final result=await AgentService().analyze(location:loc,crop:crop,farmSizeAcres:size,historicalDays:days);
      if(mounted)setState(()=>data=result);
    } catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>loading=false);}
  }

  @override Widget build(BuildContext context){
    final wide=MediaQuery.sizeOf(context).width>=900;
    return Scaffold(
      appBar:AppBar(title:const Text('AgriN Intelligence Agent',style:TextStyle(fontWeight:FontWeight.w800))),
      body:SafeArea(child:SingleChildScrollView(padding:EdgeInsets.fromLTRB(wide?56:18,18,wide?56:18,70),child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:1320),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          _hero(wide),const SizedBox(height:1),_loop(),const SizedBox(height:28),
          wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:5,child:_brief()),const SizedBox(width:26),Expanded(flex:7,child:_output())]):Column(children:[_brief(),const SizedBox(height:22),_output()]),
          if(error!=null)...[const SizedBox(height:16),_error()],
        ]),
      )))),
    );
  }

  Widget _hero(bool wide)=>Container(color:ink,padding:const EdgeInsets.fromLTRB(40,38,25,34),child:Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('AUTONOMOUS FARM DECISION LOOP / 08',style:TextStyle(color:Color(0xFF9EB6A5),fontSize:9,letterSpacing:1.9,fontWeight:FontWeight.w800)),
      const SizedBox(height:20),
      Text('From signals\nto decisions.',style:Theme.of(context).textTheme.displayMedium?.copyWith(color:Colors.white,fontSize:wide?62:45,height:.9)),
      const SizedBox(height:18),
      const Text('One agent orchestrates real weather, soil, satellite and historical observations into an evidence-grounded farm decision report.',style:TextStyle(color:Color(0xFFD1DAD3),fontSize:13,height:1.65)),
      const SizedBox(height:25),
      const Wrap(spacing:7,runSpacing:7,children:[_Tag('WEATHER'),_Tag('SOIL'),_Tag('SATELLITE'),_Tag('HISTORY'),_Tag('REASONING')]),
    ])),
    if(wide)const SizedBox(width:30),if(wide)const SizedBox(width:300,height:300,child:_AgentVisual()),
  ])).animate().fadeIn(duration:650.ms).slideY(begin:.05,end:0);

  Widget _loop()=>Container(height:88,decoration:BoxDecoration(border:Border.all(color:AgriNDesign.line)),child:Row(children:[
    _step('01','GATHER'),_arrow(),_step('02','EVIDENCE'),_arrow(),_step('03','REASON'),_arrow(),_step('04','ACT'),
  ]));
  Widget _step(String n,String label)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:Row(children:[Text(n,style:const TextStyle(fontSize:8,color:muted)),const SizedBox(width:9),Expanded(child:Text(label,style:const TextStyle(fontSize:9,letterSpacing:1.3,fontWeight:FontWeight.w800,color:ink)))])));
  Widget _arrow()=>const Icon(Icons.arrow_forward,size:15,color:Color(0xFF9AA39C));

  Widget _brief()=>Container(padding:const EdgeInsets.all(28),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.62),border:Border.all(color:AgriNDesign.line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('01 / FARM BRIEF',style:TextStyle(color:green,fontSize:9,letterSpacing:1.7,fontWeight:FontWeight.w800)),
    const SizedBox(height:10),
    Text('Give the agent a starting point.',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize:30,color:ink)),
    const SizedBox(height:8),
    const Text('The agent fetches its evidence after you submit. It does not invent missing measurements.',style:TextStyle(color:muted,fontSize:12,height:1.5)),
    const SizedBox(height:22),
    TextField(controller:location,decoration:_dec('Village / district / location',Icons.location_on_outlined)),
    const SizedBox(height:13),
    DropdownButtonFormField<String>(value:crop,decoration:_dec('Crop',Icons.grass_outlined),items:const ['Rice','Wheat','Cotton','Sugarcane','Tomato','Other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:loading?null:(x)=>setState(()=>crop=x??crop)),
    const SizedBox(height:13),
    TextField(controller:acres,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:_dec('Farm size (optional, acres)',Icons.straighten_outlined)),
    const SizedBox(height:13),
    DropdownButtonFormField<int>(value:days,decoration:_dec('Historical window',Icons.history_outlined),items:const [7,14,30,60,90].map((x)=>DropdownMenuItem(value:x,child:Text(x.toString()+' days'))).toList(),onChanged:loading?null:(x)=>setState(()=>days=x??30)),
    const SizedBox(height:20),
    SizedBox(width:double.infinity,child:ElevatedButton(onPressed:loading?null:runAgent,style:ElevatedButton.styleFrom(backgroundColor:green,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:18),shape:const RoundedRectangleBorder(borderRadius:BorderRadius.zero)),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[if(loading)const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))else const Icon(Icons.play_arrow,size:17),const SizedBox(width:9),Text(loading?'AGENT IS GATHERING EVIDENCE...':'RUN INTELLIGENCE AGENT',style:const TextStyle(fontSize:10,letterSpacing:1.3,fontWeight:FontWeight.w800))]))),
  ])).animate().fadeIn(duration:550.ms).slideX(begin:-.04,end:0);

  InputDecoration _dec(String label,IconData icon)=>InputDecoration(labelText:label,prefixIcon:Icon(icon,color:green,size:18),filled:true,fillColor:const Color(0xFFF8F8F3),border:const OutlineInputBorder(borderSide:BorderSide(color:AgriNDesign.line)),enabledBorder:const OutlineInputBorder(borderSide:BorderSide(color:AgriNDesign.line)),focusedBorder:const OutlineInputBorder(borderSide:BorderSide(color:green,width:1.3)));

  Widget _output()=>Container(padding:const EdgeInsets.all(26),decoration:BoxDecoration(color:AgriNDesign.paper2.withValues(alpha:.55),border:Border.all(color:AgriNDesign.line)),child:loading?_loadingPanel():data==null?_waiting():_report(data!));
  Widget _waiting()=>SizedBox(height:520,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    const Icon(Icons.hub_outlined,size:44,color:Color(0xFF7D8D82)),
    const SizedBox(height:16),
    const Text('AGENT OUTPUT',style:TextStyle(fontSize:9,letterSpacing:1.7,fontWeight:FontWeight.w800,color:muted)),
    const SizedBox(height:8),
    const Text('Run the agent to assemble a real evidence pack.',textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:12,height:1.5)),
  ]));

  Widget _loadingPanel()=>SizedBox(height:520,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    SizedBox(width:58,height:58,child:CircularProgressIndicator(strokeWidth:1.5,color:green,backgroundColor:const Color(0x22306B43))),
    const SizedBox(height:20),
    const Text('AGENT IS GATHERING EVIDENCE',style:TextStyle(fontSize:9,letterSpacing:1.6,fontWeight:FontWeight.w800,color:green)),
    const SizedBox(height:9),
    const Text('Resolving location and collecting live observations.',textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:12,height:1.5)),
    const SizedBox(height:22),
    Wrap(spacing:8,runSpacing:8,alignment:WrapAlignment.center,children:[
      _loadingTag('WEATHER'),_loadingTag('SOIL'),_loadingTag('SATELLITE'),_loadingTag('HISTORY'),_loadingTag('REASONING'),
    ]),
  ]));

  Widget _loadingTag(String label)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
    decoration:BoxDecoration(border:Border.all(color:const Color(0xFFB9C9BD))),
    child:Text(label,style:const TextStyle(fontSize:7.5,letterSpacing:1.1,fontWeight:FontWeight.w800,color:muted)),
  );

  Widget _report(AgentData d)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('02 / EVIDENCE PACK',style:TextStyle(color:green,fontSize:9,letterSpacing:1.7,fontWeight:FontWeight.w800)),
        SizedBox(height:10),
        Text('Agent report',style:TextStyle(fontSize:34,fontWeight:FontWeight.w600,color:ink)),
      ])),
      _statusMark(d),
    ]),
    const SizedBox(height:16),
    _summary(d),
    const SizedBox(height:24),
    _evidence(d.evidence),
    const SizedBox(height:26),
    _recommendationCards(d.report['recommendations']),
    const SizedBox(height:24),
    _textList('OBSERVATIONS',d.report['observations']),
    const SizedBox(height:22),
    _textList('NEXT CHECKS',d.report['next_checks']),
    if((d.report['limitations'] as List? ?? []).isNotEmpty)...[
      const SizedBox(height:22),
      _limitations(d.report['limitations']),
    ],
    const SizedBox(height:22),
    Container(
      width:double.infinity,
      padding:const EdgeInsets.only(top:14),
      decoration:const BoxDecoration(border:Border(top:BorderSide(color:AgriNDesign.line))),
      child:Text('SOURCES  /  '+d.sources.join(' • '),style:const TextStyle(color:muted,fontSize:9,height:1.55,letterSpacing:.25)),
    ),
  ]);

  Widget _statusMark(AgentData d)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
    decoration:BoxDecoration(border:Border.all(color:const Color(0xFF9EB6A5))),
    child:const Text('EVIDENCE GROUNDED',style:TextStyle(color:green,fontSize:8,letterSpacing:1.1,fontWeight:FontWeight.w800)),
  );

  Widget _summary(AgentData d)=>Container(
    width:double.infinity,
    padding:const EdgeInsets.all(20),
    decoration:const BoxDecoration(color:ink),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('AGENT SYNTHESIS',style:TextStyle(color:Color(0xFF9EB6A5),fontSize:8,letterSpacing:1.5,fontWeight:FontWeight.w800)),
      const SizedBox(height:9),
      Text(d.report['summary']?.toString()??'No summary returned.',style:const TextStyle(color:Color(0xFFE0E7E2),fontSize:14,height:1.65)),
    ]),
  );

  Widget _evidence(Map<String,dynamic> e)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('MEASURED / MODEL-DERIVED SIGNALS',style:TextStyle(fontSize:9,letterSpacing:1.5,fontWeight:FontWeight.w800,color:ink)),
    const SizedBox(height:10),
    Wrap(spacing:9,runSpacing:9,children:[
      _evidenceChip('WEATHER',e['weather']),
      _evidenceChip('SOIL',e['soil']),
      _evidenceChip('SATELLITE',e['satellite']),
      _evidenceChip('HISTORY',e['historical_weather']),
      _evidenceChip('NDVI HISTORY',e['historical_ndvi']),
    ]),
  ]);

  Widget _evidenceChip(String title,dynamic value)=>Container(
    width:160,
    constraints:const BoxConstraints(minHeight:104),
    padding:const EdgeInsets.all(13),
    decoration:BoxDecoration(border:Border.all(color:AgriNDesign.line),color:Colors.white.withValues(alpha:.68)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontSize:8,letterSpacing:1.2,fontWeight:FontWeight.w800,color:green)),
      const SizedBox(height:8),
      Text(_compact(value),maxLines:5,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9.5,height:1.45,color:muted)),
    ]),
  );

  String _compact(dynamic v){
    if(v==null)return 'Unavailable';
    if(v is Map){
      final entries=v.entries.where((e)=>e.value!=null).take(3);
      final parts=entries.map((e)=>e.key.toString()+': '+e.value.toString()).toList();
      return parts.isEmpty?'Unavailable':parts.join('\n');
    }
    return v.toString();
  }

  Widget _recommendationCards(dynamic raw)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('RECOMMENDATIONS',style:TextStyle(fontSize:9,letterSpacing:1.5,fontWeight:FontWeight.w800,color:green)),
    const SizedBox(height:10),
    ...(raw is List?raw:const []).asMap().entries.map((entry){
      final item=entry.value is Map?Map<String,dynamic>.from(entry.value as Map):<String,dynamic>{'title':entry.value};
      final priority=item['priority']?.toString().toUpperCase()??'';
      final evidence=(item['evidence'] as List? ?? []).join(' • ');
      return Container(
        margin:const EdgeInsets.only(bottom:10),
        padding:const EdgeInsets.all(15),
        decoration:BoxDecoration(
          color:Colors.white.withValues(alpha:.72),
          border:Border.all(color:AgriNDesign.line),
        ),
        child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(
            width:28,height:28,
            alignment:Alignment.center,
            decoration:BoxDecoration(color:const Color(0xFFE8EFE9),border:Border.all(color:const Color(0xFFB9C9BD))),
            child:Text((entry.key+1).toString().padLeft(2,'0'),style:const TextStyle(fontSize:8,fontWeight:FontWeight.w800,color:green)),
          ),
          const SizedBox(width:13),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Expanded(child:Text(item['title']?.toString()??'Action',style:const TextStyle(fontSize:12.5,fontWeight:FontWeight.w800,color:ink))),
              if(priority.isNotEmpty)Text(priority,style:const TextStyle(fontSize:7.5,letterSpacing:1,color:green,fontWeight:FontWeight.w800)),
            ]),
            const SizedBox(height:5),
            Text(item['reason']?.toString()??'',style:const TextStyle(fontSize:10.5,height:1.55,color:muted)),
            if(evidence.isNotEmpty)...[
              const SizedBox(height:8),
              Text('EVIDENCE  /  $evidence',style:const TextStyle(fontSize:8.5,height:1.45,color:ink)),
            ],
          ])),
        ]),
      );
    }),
  ]);

  Widget _textList(String title,dynamic raw)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(fontSize:9,letterSpacing:1.5,fontWeight:FontWeight.w800,color:green)),
    const SizedBox(height:7),
    ...(raw is List?raw:const []).asMap().entries.map((entry)=>Container(
      padding:const EdgeInsets.symmetric(vertical:9),
      decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:AgriNDesign.line))),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text((entry.key+1).toString().padLeft(2,'0'),style:const TextStyle(fontSize:8,color:muted)),
        const SizedBox(width:10),
        Expanded(child:Text(_recommendationText(entry.value),style:const TextStyle(fontSize:10.5,height:1.55,color:ink))),
      ]),
    )),
  ]);

  Widget _limitations(dynamic raw)=>Container(
    width:double.infinity,
    padding:const EdgeInsets.all(15),
    decoration:BoxDecoration(color:const Color(0xFFF4F1E9),border:Border.all(color:AgriNDesign.line)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('LIMITATIONS / READ BEFORE ACTING',style:TextStyle(fontSize:8.5,letterSpacing:1.4,fontWeight:FontWeight.w800,color:muted)),
      const SizedBox(height:7),
      ...(raw is List?raw:const []).map((item)=>Padding(
        padding:const EdgeInsets.only(bottom:5),
        child:Text('• '+item.toString(),style:const TextStyle(fontSize:9.5,height:1.45,color:muted)),
      )),
    ]),
  );

  String _recommendationText(dynamic v){
    if(v is Map){
      final title=v['title']?.toString()??'';
      final reason=v['reason']?.toString()??'';
      final evidence=(v['evidence'] as List? ?? []).join(' • ');
      return evidence.isEmpty?title+' — '+reason:title+' — '+reason+'\\nEvidence: '+evidence;
    }
    return v.toString();
  }

  Widget _error()=>Container(
    width:double.infinity,
    padding:const EdgeInsets.all(16),
    decoration:const BoxDecoration(color:Color(0xFFFFF1EC),border:Border(left:BorderSide(color:Colors.deepOrange,width:3))),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.error_outline,size:18,color:Colors.deepOrange),
      const SizedBox(width:10),
      Expanded(child:Text(error!,style:const TextStyle(color:ink,fontSize:12,height:1.5))),
      const SizedBox(width:10),
      TextButton(
        onPressed:loading?null:runAgent,
        child:const Text('RETRY',style:TextStyle(fontSize:9,letterSpacing:1.1,fontWeight:FontWeight.w800,color:green)),
      ),
    ]),
  );
}

class _Tag extends StatelessWidget { const _Tag(this.text); final String text; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(border:Border.all(color:const Color(0x445B765F))),child:Text(text,style:const TextStyle(color:Color(0xFFB5C5BA),fontSize:8,letterSpacing:1.3,fontWeight:FontWeight.w700))); }
class _AgentVisual extends StatelessWidget {
  const _AgentVisual();
  @override Widget build(BuildContext context)=>Stack(alignment:Alignment.center,children:[
    Container(width:285,height:285,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0x335E7865)))),
    Container(width:220,height:220,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0x6685A18B)))),
    Container(width:110,height:110,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0x332E6B43),border:Border.all(color:const Color(0x889AB6A2))),child:const Icon(Icons.hub_outlined,color:Color(0xFFD8E3DB),size:40)),
    const Positioned(top:18,left:25,child:_Tag('WEATHER')),const Positioned(right:10,top:75,child:_Tag('SOIL')),
    const Positioned(right:20,bottom:48,child:_Tag('SATELLITE')),const Positioned(left:10,bottom:35,child:_Tag('HISTORY')),
  ]);
}
