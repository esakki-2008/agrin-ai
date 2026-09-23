import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/weather_service.dart';
import '../../services/soil_service.dart';
import '../../services/satellite_service.dart';
import '../../services/advisory_service.dart';
import '../../services/climate_service.dart';
import '../../services/soil_intelligence_service.dart';
import '../../services/water_intelligence_service.dart';
import '../../theme/agri_n_design.dart';

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
  AdvancedSatelliteData? advancedSatellite;
  ClimateIntelligenceData? climate;
  SoilProfileData? soilProfile;
  WaterIntelligenceData? waterIntelligence;
  AdvisoryData? advisory;
  String? error;
  bool advisoryUnavailable=false;

  @override void dispose(){location.dispose();size.dispose();super.dispose();}

  Future<void> pickDate() async {
    final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime.now(),initialDate:date??DateTime.now());
    if(d!=null)setState(()=>date=d);
  }

  Future<void> analyze() async {
    if(location.text.trim().isEmpty||size.text.trim().isEmpty||date==null){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Please complete your farm details first.'))); return;
    }

    setState(() {
      analyzing=true;
      error=null;
      weather=null;
      soil=null;
      satellite=null;
      advancedSatellite=null;
      climate=null;
      soilProfile=null;
      waterIntelligence=null;
      advisory=null;
      advisoryUnavailable=false;
      showResults=false;
    });

    try {
      // Resolve the location first. Everything else can then load concurrently.
      final liveWeather=await WeatherService().fetch(location.text.trim());
      if(!mounted)return;
      setState(() {
        weather=liveWeather;
        // Render the page as soon as the first real observation arrives.
        // Remaining live sources stream into the already-visible result view.
        showResults=true;
      });

      final acres=double.tryParse(size.text.trim());
      if(acres==null) throw Exception('Farm size must be a valid number.');

      Future<void> loadSoil() async {
        try {
          final value=await SoilService().fetch(
            latitude:liveWeather.latitude,
            longitude:liveWeather.longitude,
          );
          if(mounted)setState(()=>soil=value);
        } catch(e) {
          if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
        }
      }

      Future<void> loadSatellite() async {
        try {
          final value=await SatelliteService().fetch(
            latitude:liveWeather.latitude,
            longitude:liveWeather.longitude,
          );
          if(mounted)setState(()=>satellite=value);
        } catch(e) {
          if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
        }
      }

      Future<void> loadAdvancedSatellite() async {
        try {
          final value=await SatelliteService().fetchIntelligence(
            latitude:liveWeather.latitude,
            longitude:liveWeather.longitude,
            days:180,
            maxCloudCover:30,
          );
          if(mounted)setState(()=>advancedSatellite=value);
        } catch(e) {
          if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
        }
      }

      Future<void> loadClimate() async {
        try {
          final value=await ClimateService().fetch(
            latitude:liveWeather.latitude,
            longitude:liveWeather.longitude,
            forecastDays:7,
          );
          if(mounted)setState(()=>climate=value);
        } catch(e) {
          if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
        }
      }

      Future<void> loadSoilProfile() async {
        try {
          final value=await SoilIntelligenceService().fetch(
            latitude:liveWeather.latitude,
            longitude:liveWeather.longitude,
          );
          if(mounted)setState(()=>soilProfile=value);
        } catch(e) {
          if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
        }
      }

      Future<void> loadWater() async {
        try {
          final value=await WaterIntelligenceService().fetch(
            latitude:liveWeather.latitude,
            longitude:liveWeather.longitude,
            forecastDays:7,
          );
          if(mounted)setState(()=>waterIntelligence=value);
        } catch(e) {
          if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
        }
      }

      // These sources are independent after geocoding, so don't wait for them
      // one-by-one. Each section appears as soon as its real response arrives.
      final soilLoad=loadSoil();
      final satelliteLoad=loadSatellite();
      final sourceLoads=Future.wait<void>([
        soilLoad,
        satelliteLoad,
        loadAdvancedSatellite(),
        loadClimate(),
        loadSoilProfile(),
        loadWater(),
      ]);

      // AI can start as soon as the core observations needed by the advisory
      // are available. It no longer blocks the environmental intelligence UI.
      try {
        await Future.wait<void>([soilLoad,satelliteLoad]);
        final ai=await AdvisoryService().fetch(
          location:location.text.trim(),
          crop:crop,
          farmSizeAcres:acres,
          sowingDate:date!,
          weather:liveWeather,
          soil:soil,
          satellite:satellite,
        );
        if(mounted)setState(()=>advisory=ai);
      } catch(e) {
        if(mounted)setState(()=>advisoryUnavailable=true);
      }

      await sourceLoads;
    } catch(e) {
      if(mounted){
        setState(() {
          error=e.toString().replaceFirst('Exception: ','');
          analyzing=false;
          showResults=weather!=null;
        });
      }
      return;
    }

    if(mounted)setState(()=>analyzing=false);
  }

  InputDecoration decoration(String label,IconData icon)=>InputDecoration(
    labelText:label,prefixIcon:Icon(icon,color:green),filled:true,fillColor:const Color(0xFFF7F9F5),
    border:OutlineInputBorder(borderRadius:BorderRadius.zero,borderSide:BorderSide.none),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.zero,borderSide:const BorderSide(color:green,width:1.4)),
  );

  @override Widget build(BuildContext context){
    final wide=MediaQuery.sizeOf(context).width>=900;
    return Scaffold(
      appBar:AppBar(title:const Text('Farm Intelligence',style:TextStyle(fontWeight:FontWeight.w800))),
      body:SafeArea(child:SingleChildScrollView(padding:EdgeInsets.all(wide?48:20),child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:1100),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          _header(),const SizedBox(height:14),
          _signalPipeline(),const SizedBox(height:22),
          if(!showResults) ...[
            wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:_form()),const SizedBox(width:20),Expanded(child:_preview())])
              :Column(children:[_form(),const SizedBox(height:20),_preview()]),
          ] else _results(wide),
        ]),
      )))),
    );
  }

  Widget _header() => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 390),
    decoration: const BoxDecoration(
      color: AgriNDesign.ink,
      border: Border.fromBorderSide(BorderSide(color: AgriNDesign.ink)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 720;
        final visual = SizedBox(
          width: wide ? 390 : double.infinity,
          height: wide ? 390 : 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const MotionOrb(size: 190, label: 'FIELD'),
              Container(
                width: 270,
                height: 270,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x445A765F)),
                ),
              ),
              Container(
                width: 205,
                height: 205,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x667D9A83)),
                ),
              ),
              Container(
                width: 125,
                height: 125,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AgriNDesign.green.withValues(alpha: .25),
                  border: Border.all(color: const Color(0x8895B29C)),
                ),
                child: const Icon(Icons.eco_outlined, color: Color(0xFFD6E1D9), size: 34),
              ),
              Positioned(
                top: 26,
                right: 24,
                child: _heroNode('WEATHER', Icons.cloud_outlined),
              ),
              Positioned(
                bottom: 26,
                left: 18,
                child: _heroNode('SOIL', Icons.layers_outlined),
              ),
              Positioned(
                bottom: 48,
                right: 6,
                child: _heroNode('SATELLITE', Icons.satellite_alt_outlined),
              ),
            ],
          ),
        );

        final copy = Padding(
          padding: const EdgeInsets.fromLTRB(42, 38, 24, 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.eco_outlined, color: Color(0xFF9EB6A5), size: 18),
                  SizedBox(width: 10),
                  Text(
                    'AGRI N / FIELD INTELLIGENCE',
                    style: TextStyle(
                      color: Color(0xFFB4C0B7),
                      fontSize: 9,
                      letterSpacing: 1.9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'LIVE EVIDENCE  /  01',
                    style: TextStyle(
                      color: Color(0xFF8FA196),
                      fontSize: 8,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 45),
              Text(
                'Let’s understand\\nyour farm.',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontSize: wide ? 62 : 43,
                      height: .9,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 490,
                child: Text(
                  'Build a localized intelligence profile from live weather, soil and satellite observations.',
                  style: TextStyle(
                    color: Color(0xFFD1DAD3),
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: const [
                  _HeroTag('WEATHER'),
                  SizedBox(width: 7),
                  _HeroTag('SOIL'),
                  SizedBox(width: 7),
                  _HeroTag('SATELLITE'),
                  SizedBox(width: 7),
                  _HeroTag('AI'),
                ],
              ),
            ],
          ),
        );

        return wide
            ? Row(
                children: [
                  Expanded(child: copy),
                  visual,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, visual],
              );
      },
    ),
  ).animate().fadeIn(duration: 600.ms).slideY(begin: .05, end: 0);

  Widget _heroNode(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xDD151914),
      border: Border.all(color: const Color(0x446F8C76)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFFA5B8AA)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB5C2B9),
            fontSize: 7,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _signalPipeline() {
    const items = [
      ('01', 'WEATHER', 'LIVE FORECAST', Icons.cloud_outlined),
      ('02', 'SOIL', 'SOILGRIDS MODEL', Icons.layers_outlined),
      ('03', 'SATELLITE', 'SENTINEL-2', Icons.satellite_alt_outlined),
      ('04', 'AI', 'EVIDENCE REASONING', Icons.auto_awesome_outlined),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AgriNDesign.line),
          bottom: BorderSide(color: AgriNDesign.line),
        ),
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Expanded(
            child: Container(
              height: 92,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: i == 3 ? AgriNDesign.ink : Colors.transparent,
                border: Border(
                  right: BorderSide(
                    color: AgriNDesign.line,
                    width: i == items.length - 1 ? 0 : 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    item.$1,
                    style: const TextStyle(fontSize: 8, color: AgriNDesign.muted),
                  ),
                  const SizedBox(width: 13),
                  Icon(
                    item.$4,
                    size: 17,
                    color: i == 3 ? const Color(0xFFB7C8BC) : AgriNDesign.green,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: TextStyle(
                            color: i == 3 ? Colors.white : AgriNDesign.ink,
                            fontSize: 9,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.$3,
                          style: TextStyle(
                            color: i == 3 ? const Color(0xFF9EADA3) : AgriNDesign.muted,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate(delay: (90 * i).ms).fadeIn(duration: 450.ms).slideX(begin: .04, end: 0);
        }).toList(),
      ),
    );
  }

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
      style:ElevatedButton.styleFrom(backgroundColor:green,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.zero)))),
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
    if(advancedSatellite!=null) _advancedSatelliteSection(advancedSatellite!,wide),
    if(climate!=null) _climateSection(climate!,wide),
    if(soilProfile!=null) _soilProfileSection(soilProfile!,wide),
    if(waterIntelligence!=null) _waterIntelligenceSection(waterIntelligence!,wide),
    const SizedBox(height:20),
    if(error!=null) _errorCard(),
    if(advisory!=null) _aiAdvisory(advisory!),
    if(advisory==null) _advisory(),
    const SizedBox(height:16),
    _signalCard('Connected live sources','Open-Meteo • ISRIC SoilGrids • Sentinel-2',Icons.hub_rounded),
  ]).animate().fadeIn(duration:650.ms).slideY(begin:.06,end:0);

  Widget _soilProfileSection(SoilProfileData data, bool wide) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Multi-depth soil intelligence', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: dark)),
    const SizedBox(height: 8),
    Text(data.source + ' • ' + data.resolution.toString() + ' m model resolution', style: const TextStyle(fontSize: 11, color: muted)),
    const SizedBox(height: 12),
    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: wide ? 3 : 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
      children: List.generate(data.profile.length, (i) {
        final row = data.profile[i];
        final depth = row is Map ? row['depth']?.toString() ?? 'Depth ' + (i + 1).toString() : 'Depth ' + (i + 1).toString();
        final ph = data.value(i, 'ph');
        final carbon = data.value(i, 'organic_carbon_g_kg');
        return _metric((ph == null ? 'Unavailable' : ph.toStringAsFixed(2)) + ' pH\\n' + (carbon == null ? 'Unavailable' : carbon.toStringAsFixed(1)) + ' g/kg C', depth, Icons.layers_outlined);
      }),
    ),
    const SizedBox(height: 20),
  ]);

  Widget _waterIntelligenceSection(WaterIntelligenceData data, bool wide) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Water & irrigation intelligence', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: dark)),
    const SizedBox(height: 8),
    Text(data.source, style: const TextStyle(fontSize: 11, color: muted)),
    const SizedBox(height: 12),
    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: wide ? 4 : 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5, children: [
      _metric(data.metric('forecast_precipitation_mm'), 'Forecast rain (mm)', Icons.water_drop_outlined),
      _metric(data.metric('reference_et0_mm'), 'Reference ET0 (mm)', Icons.wb_sunny_outlined),
      _metric(data.metric('water_balance_mm'), 'Atmospheric balance (mm)', Icons.balance_outlined),
      _metric(data.metric('max_rain_probability_percent'), 'Max rain probability', Icons.umbrella_outlined),
    ]),
    const SizedBox(height: 10),
    if (data.signals.isNotEmpty) _signalCard('Water signals', data.signals.map((x) => '• ' + x.toString()).join('\\n'), Icons.water_drop_outlined),
    const SizedBox(height: 20),
  ]);

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

  Widget _advancedSatelliteSection(AdvancedSatelliteData data, bool wide) {
    if (!data.available) {
      return _card('Advanced satellite intelligence', const Text(
        'No Sentinel-2 scene met the requested cloud threshold. No satellite index is shown.',
        style: TextStyle(color: muted),
      ));
    }
    final ndvi=data.index('latest','ndvi');
    final ndmi=data.index('latest','ndmi');
    final evi=data.index('latest','evi');
    final ndviDelta=data.delta('ndvi');
    final ndmiDelta=data.delta('ndmi');
    final eviDelta=data.delta('evi');
    String fmt(double? value) => value==null ? 'Unavailable' : value.toStringAsFixed(3);
    String fmtChange(double? value) => value==null ? 'No paired observation' : (value>=0?'+':'')+value.toStringAsFixed(3);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Expanded(child:Text('Advanced satellite intelligence',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:dark))),
        const Icon(Icons.satellite_alt_rounded,color:green,size:22),
      ]),
      const SizedBox(height:8),
      const Text(
        'Cloud-aware Sentinel-2 selection with vegetation and moisture indices. Values are point samples, not whole-farm scores.',
        style: TextStyle(fontSize:11,color:muted,height:1.5),
      ),
      const SizedBox(height:12),
      GridView.count(
        shrinkWrap:true,
        physics:const NeverScrollableScrollPhysics(),
        crossAxisCount:wide?3:2,
        crossAxisSpacing:12,
        mainAxisSpacing:12,
        childAspectRatio:1.45,
        children:[
          _metric(fmt(ndvi),'Latest NDVI • Δ '+fmtChange(ndviDelta),Icons.eco_rounded),
          _metric(fmt(ndmi),'Latest NDMI • Δ '+fmtChange(ndmiDelta),Icons.water_drop_outlined),
          _metric(fmt(evi),'Latest EVI • Δ '+fmtChange(eviDelta),Icons.grass_outlined),
        ],
      ),
      const SizedBox(height:10),
      _signalCard(
        'Cloud-aware observation',
        'Latest: '+(data.sceneDate('latest')?.substring(0,10) ?? 'Unavailable')+' • '+(data.sceneCloud('latest')?.toStringAsFixed(1) ?? 'Unavailable')+'% cloud',
        Icons.filter_alt_outlined,
      ),
      const SizedBox(height:20),
    ]);
  }

  Widget _climateSection(ClimateIntelligenceData data, bool wide) {
    final rain=data.number('total_forecast_precipitation_mm');
    final et0=data.number('total_reference_et0_mm');
    final maxTemp=data.number('maximum_temperature_c');
    final maxWind=data.number('maximum_wind_kmh');
    String fmt(double? value,String unit) => value==null ? 'Unavailable' : value.toStringAsFixed(1)+unit;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Expanded(child:Text('Climate & weather intelligence',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:dark))),
        const Icon(Icons.cloud_outlined,color:green,size:22),
      ]),
      const SizedBox(height:8),
      const Text(
        'Seven-day forecast signals from Open-Meteo. Forecasts can change as the model updates.',
        style:TextStyle(fontSize:11,color:muted,height:1.5),
      ),
      const SizedBox(height:12),
      GridView.count(
        shrinkWrap:true,
        physics:const NeverScrollableScrollPhysics(),
        crossAxisCount:wide?4:2,
        crossAxisSpacing:12,
        mainAxisSpacing:12,
        childAspectRatio:1.45,
        children:[
          _metric(fmt(rain,' mm'),'Forecast precipitation',Icons.umbrella_outlined),
          _metric(fmt(et0,' mm'),'Reference ET0',Icons.wb_sunny_outlined),
          _metric(fmt(maxTemp,'°C'),'Maximum temperature',Icons.thermostat_outlined),
          _metric(fmt(maxWind,' km/h'),'Maximum wind',Icons.air_outlined),
        ],
      ),
      const SizedBox(height:10),
      if(data.signals.isNotEmpty)
        _signalCard(
          'Climate signals',
          data.signals.map((item)=>item is Map ? (item['evidence']?.toString() ?? '') : '').where((x)=>x.isNotEmpty).join(' • '),
          Icons.insights_outlined,
        )
      else
        _signalCard('Climate signals','No screening signal triggered by the available forecast values.',Icons.insights_outlined),
      const SizedBox(height:20),
    ]);
  }

  Widget _metric(String value,String label,IconData icon)=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(2),border:Border.all(color:AgriNDesign.line)),
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

  Widget _errorCard()=>Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFFFF3F0),borderRadius:BorderRadius.zero),child:Row(children:[const Icon(Icons.error_outline,color:Colors.deepOrange),const SizedBox(width:10),Expanded(child:Text(error??'Unable to fetch live data.',style:const TextStyle(color:dark)))]));
  Widget _aiAdvisory(AdvisoryData data) {
    return Container(
      width:double.infinity,
      padding:const EdgeInsets.all(22),
      decoration:BoxDecoration(color:dark,borderRadius:BorderRadius.zero),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[
          Icon(Icons.auto_awesome_rounded,color:Colors.white),
          SizedBox(width:10),
          Text('AI Agro-Advisory',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)),
        ]),
        const SizedBox(height:16),
        Text(data.summary,style:const TextStyle(color:Color(0xFFD4DDD7),height:1.55)),
        if(data.actions.isNotEmpty) ...[
          const SizedBox(height:18),
          ...data.actions.map((a)=>Container(
            margin:const EdgeInsets.only(bottom:10),
            padding:const EdgeInsets.all(14),
            decoration:BoxDecoration(color:const Color(0xFF1C3325),borderRadius:BorderRadius.zero),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(a.title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),
              const SizedBox(height:5),
              Text(a.reason,style:const TextStyle(color:Color(0xFFD4DDD7),fontSize:12,height:1.4)),
              const SizedBox(height:5),
              Text('Priority: ${a.priority} • Confidence: ${a.confidence}',style:const TextStyle(color:Color(0xFF9FB0A4),fontSize:10)),
            ]),
          )),
        ],
        if(data.watchItems.isNotEmpty) ...[
          const SizedBox(height:6),
          const Text('Watch next',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),
          const SizedBox(height:7),
          ...data.watchItems.map((x)=>Padding(padding:const EdgeInsets.only(bottom:5),child:Text('• $x',style:const TextStyle(color:Color(0xFFD4DDD7),fontSize:12)))),
        ],
        if(data.dataLimits.isNotEmpty) ...[
          const SizedBox(height:12),
          Text('Data limits: ${data.dataLimits.join(' • ')}',style:const TextStyle(color:Color(0xFF9FB0A4),fontSize:10,height:1.4)),
        ],
        const SizedBox(height:12),
        Text('${data.source} • ${data.model}',style:const TextStyle(color:Color(0xFF9FB0A4),fontSize:10)),
      ]),
    );
  }

  Widget _advisory() {
    if (advisoryUnavailable) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.zero),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('AI Agro-Advisory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            SizedBox(height: 16),
            Text(
              'AI Advisory is currently unavailable because no AI provider is configured. Live environmental intelligence remains available from the connected data sources.',
              style: TextStyle(color: Color(0xFFD4DDD7), height: 1.55),
            ),
            SizedBox(height: 14),
            Text(
              'No generated recommendation is shown while the AI provider is unavailable.',
              style: TextStyle(color: Color(0xFF9FB0A4), fontSize: 11),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.zero,
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
        borderRadius: BorderRadius.zero,
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
        borderRadius: BorderRadius.zero,
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


class _HeroTag extends StatelessWidget {
  const _HeroTag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x445B765F)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB5C5BA),
          fontSize: 8,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
