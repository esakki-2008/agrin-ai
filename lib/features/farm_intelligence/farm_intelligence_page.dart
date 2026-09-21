import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/weather_service.dart';
import '../../services/soil_service.dart';
import '../../services/satellite_service.dart';

class FarmIntelligencePage extends StatefulWidget {
  const FarmIntelligencePage({super.key});
  @override State<FarmIntelligencePage> createState() => _FarmIntelligencePageState();
}

class _FarmIntelligencePageState extends State<FarmIntelligencePage> {
  static const green=Color(0xFF2E6B43), dark=Color(0xFF102318), muted=Color(0xFF66736A);
  final location=TextEditingController(), size=TextEditingController();
  String crop='Rice'; DateTime? date; bool analyzing=false, showResults=false;
  WeatherData? weather;
  SoilData? soil;
  SatelliteData? satellite;
  String? error;

  @override void dispose(){location.dispose();size.dispose();super.dispose();}

  Future<void> pickDate() async {
    final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime.now(),initialDate:date??DateTime.now());
    if(d!=null)setState(()=>date=d);
  }

  Future<void> analyze() async {
    if(location.text.trim().isEmpty||size.text.trim().isEmpty||date==null){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Please complete your farm details first.'))); return;
    }
    setState(() { analyzing=true; error=null; weather=null; soil=null; satellite=null; showResults=false; });
    try {
      final liveWeather=await WeatherService().fetch(location.text.trim());
      if(mounted)setState(()=>weather=liveWeather);
      final liveSoil=await SoilService().fetch(latitude:liveWeather.latitude, longitude:liveWeather.longitude);
      if(mounted)setState(()=>soil=liveSoil);
      try {
        final liveSatellite=await SatelliteService().fetch(latitude:liveWeather.latitude, longitude:liveWeather.longitude);
        if(mounted)setState(()=>satellite=liveSatellite);
      } catch(e) {
        if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
      }
    } catch(e) {
      if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
    }
    if(mounted)setState(()=>analyzing=false);
    if(mounted && weather!=null)setState(()=>showResults=true);
  }

  InputDecoration decoration(String label,IconData icon)=>InputDecoration(
    labelText:label,prefixIcon:Icon(icon,color:green),filled:true,fillColor:const Color(0xFFF7F9F5),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:green,width:1.4)),
  );

  @override Widget build(BuildContext context){
    final wide=MediaQuery.sizeOf(context).width>=900;
    return Scaffold(
      appBar:AppBar(title:const Text('Farm Intelligence',style:TextStyle(fontWeight:FontWeight.w800))),
      body:SafeArea(child:SingleChildScrollView(padding:EdgeInsets.all(wide?48:20),child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:1100),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          _header(),const SizedBox(height:22),
          if(!showResults) ...[
            wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:_form()),const SizedBox(width:20),Expanded(child:_preview())])
              :Column(children:[_form(),const SizedBox(height:20),_preview()]),
          ] else _results(wide),
        ]),
      )))),
    );
  }

  Widget _header()=>Container(width:double.infinity,padding:const EdgeInsets.all(28),decoration:BoxDecoration(
    gradient:const LinearGradient(colors:[Color(0xFF173B26),Color(0xFF3F7D4C)]),borderRadius:BorderRadius.circular(28)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(Icons.satellite_alt_rounded,color:Colors.white,size:34),SizedBox(height:14),
      Text('Let’s understand your farm',style:TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w800)),
      SizedBox(height:8),Text('Build a localized intelligence profile from your farm details.',style:TextStyle(color:Color(0xCCDDE9DF),height:1.5)),
    ])).animate().fadeIn(duration:600.ms).slideY(begin:.06,end:0);

  Widget _form()=>_card('Farm profile',Column(children:[
    TextField(controller:location,decoration:decoration('Village / district / location',Icons.location_on_outlined)),
    const SizedBox(height:15),
    DropdownButtonFormField<String>(value:crop,decoration:decoration('Primary crop',Icons.grass_rounded),
      items:const ['Rice','Wheat','Cotton','Sugarcane','Tomato','Other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
      onChanged:(x)=>setState(()=>crop=x??crop)),
    const SizedBox(height:15),
    TextField(controller:size,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:decoration('Farm size (acres)',Icons.straighten_rounded)),
    const SizedBox(height:15),
    InkWell(onTap:pickDate,child:InputDecorator(decoration:decoration('Sowing date',Icons.calendar_month_outlined),
      child:Text(date==null?'Select sowing date':date!.day.toString().padLeft(2,'0')+'/'+date!.month.toString().padLeft(2,'0')+'/'+date!.year.toString()))),
    const SizedBox(height:20),
    SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:analyzing?null:analyze,icon:analyzing?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.auto_awesome_rounded),
      label:Padding(padding:const EdgeInsets.symmetric(vertical:15),child:Text(analyzing?'Analyzing farm signals...':'Analyze my farm')),
      style:ElevatedButton.styleFrom(backgroundColor:green,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))))),
  ])).animate().fadeIn(duration:550.ms).slideX(begin:-.04,end:0);

  Widget _preview()=>_card('Intelligence layers',const Column(children:[
    ListTile(leading:Icon(Icons.cloud_outlined,color:green),title:Text('Weather'),subtitle:Text('Forecast and climate-risk signals')),
    ListTile(leading:Icon(Icons.water_drop_outlined,color:green),title:Text('Soil'),subtitle:Text('Moisture and soil-health indicators')),
    ListTile(leading:Icon(Icons.satellite_alt_outlined,color:green),title:Text('Satellite'),subtitle:Text('Vegetation and water-stress signals')),
    ListTile(leading:Icon(Icons.auto_awesome_rounded,color:green),title:Text('AI Advisory'),subtitle:Text('Localized actions explained simply')),
  ])).animate(delay:150.ms).fadeIn(duration:550.ms).slideX(begin:.04,end:0);

  Widget _results(bool wide)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Farm intelligence',style:TextStyle(fontSize:wide?32:27,fontWeight:FontWeight.w800,color:dark)),
    const SizedBox(height:6),
    Text(location.text+' • '+crop+' • '+size.text+' acres',style:const TextStyle(color:muted)),
    const SizedBox(height:20),
    GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:wide?4:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.5,
      children:[
        _metric('${weather!.temperature.toStringAsFixed(1)}°C','Live temperature',Icons.thermostat_rounded),
        _metric('${weather!.humidity.toStringAsFixed(0)}%','Live humidity',Icons.water_drop_rounded),
        _metric('${weather!.windSpeed.toStringAsFixed(1)} km/h','Live wind',Icons.air_rounded),
        _metric('${weather!.rainProbability}%','Rain probability',Icons.umbrella_rounded),
      ]),
    const SizedBox(height:20),
    if(soil!=null) _soilSection(soil!,wide),
    if(satellite!=null) _satelliteSection(satellite!,wide),
    const SizedBox(height:20),
    if(error!=null) _errorCard(),
    _advisory(),
    const SizedBox(height:16),
    _signalCard('Connected live sources','Open-Meteo • ISRIC SoilGrids • Sentinel-2',Icons.hub_rounded),
  ]).animate().fadeIn(duration:650.ms).slideY(begin:.06,end:0);

  Widget _soilSection(SoilData data, bool wide)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[
      const Expanded(child:Text('Soil intelligence',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:dark))),
      Text(data.depth,style:const TextStyle(fontSize:11,color:muted)),
    ]),
    const SizedBox(height:10),
    Text('${data.source} • ${data.resolution} m model resolution',style:const TextStyle(fontSize:11,color:muted)),
    const SizedBox(height:12),
    GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:wide?4:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.5,children:[
      _metric(data.ph.toStringAsFixed(2),'Soil pH',Icons.science_outlined),
      _metric('${data.organicCarbon.toStringAsFixed(1)} g/kg','Organic carbon',Icons.eco_outlined),
      _metric('${data.nitrogen.toStringAsFixed(3)} g/kg','Total nitrogen',Icons.grass_outlined),
      _metric('${data.clay.toStringAsFixed(1)}%','Clay content',Icons.layers_outlined),
    ]),
    const SizedBox(height:20),
  ]);

  Widget _satelliteSection(SatelliteData data, bool wide)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[
      const Expanded(child:Text('Satellite vegetation',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:dark))),
      const Icon(Icons.satellite_alt_rounded,color:green,size:22),
    ]),
    const SizedBox(height:8),
    Text(data.source,style:const TextStyle(fontSize:11,color:muted)),
    const SizedBox(height:12),
    GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:wide?3:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.5,children:[
      _metric(data.ndvi==null?'Unavailable':data.ndvi!.toStringAsFixed(3),'NDVI',Icons.eco_rounded),
      _metric(data.cloudCover==null?'Unavailable':'${data.cloudCover!.toStringAsFixed(1)}%','Scene cloud cover',Icons.cloud_outlined),
      _metric(data.observationDate==null?'Unavailable':data.observationDate!.substring(0,10),'Observation date',Icons.calendar_today_outlined),
    ]),
    const SizedBox(height:8),
    Text(data.sceneId==null?'Scene ID unavailable':'Scene: ${data.sceneId}',style:const TextStyle(fontSize:10,color:muted)),
    const SizedBox(height:20),
  ]);

  Widget _metric(String value,String label,IconData icon)=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:const Color(0xFFE5EAE5))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,color:green,size:22),const SizedBox(height:12),Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:dark)),Text(label,style:const TextStyle(fontSize:11,color:muted)),
    ]));

  String _condition(int? code) {
    if (code == null) return 'Weather condition unavailable';
    if (code == 0) return 'Clear sky';
    if (code == 1 || code == 2 || code == 3) return 'Partly cloudy';
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Variable conditions';
  }

  Widget _errorCard()=>Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFFFF3F0),borderRadius:BorderRadius.circular(18)),child:Row(children:[const Icon(Icons.error_outline,color:Colors.deepOrange),const SizedBox(width:10),Expanded(child:Text(error??'Unable to fetch live data.',style:const TextStyle(color:dark)))]));
  Widget _advisory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'AI Agro-Advisory',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Your farm profile is ready. AgriN will combine live environmental signals with crop context to recommend irrigation, crop-care and climate-resilience actions.',
            style: TextStyle(color: Color(0xFFD4DDD7), height: 1.55),
          ),
          const SizedBox(height: 14),
          Text(
            '${_condition(weather?.weatherCode)} • Live weather source: Open-Meteo • Location resolved from your input',
            style: const TextStyle(color: Color(0xFF9FB0A4), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _signalCard(String title, String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5EAE5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFEAF4EC), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: dark)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(fontSize: 12, color: muted)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EAE5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: dark)),
        const SizedBox(height: 18),
        child,
      ]),
    );
  }
}
