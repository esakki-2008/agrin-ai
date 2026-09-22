import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/disease_service.dart';
import '../../theme/agri_n_design.dart';


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
  late final AnimationController _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void dispose() { crop.dispose(); location.dispose(); _scanController.dispose(); super.dispose(); }

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
    _scanController.repeat();
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
      _scanController.stop();
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
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 370),
    color: dark,
    child: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 720;
      final copy = Padding(
        padding: const EdgeInsets.fromLTRB(42, 38, 25, 38),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.center_focus_strong_outlined, color: Color(0xFF9EB6A5), size: 18),
            SizedBox(width: 10),
            Text('VISUAL CROP INTELLIGENCE', style: TextStyle(color: Color(0xFFB4C0B7), fontSize: 9, letterSpacing: 1.9, fontWeight: FontWeight.w800)),
            Spacer(),
            Text('IMAGE ANALYSIS  /  02', style: TextStyle(color: Color(0xFF8FA196), fontSize: 8, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 42),
          Text('See what your\ncrop is telling you.', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white, fontSize: wide ? 57 : 43, height: .9)),
          const SizedBox(height: 19),
          const SizedBox(width: 500, child: Text('Upload a clear leaf or crop image and turn visible evidence into an explainable AI assessment.', style: TextStyle(color: Color(0xFFD1DAD3), fontSize: 13, height: 1.65))),
          const SizedBox(height: 26),
          const Row(children: [
            _HeroTag('IMAGE'), SizedBox(width: 7), _HeroTag('VISION'), SizedBox(width: 7), _HeroTag('EXPLAINABLE'),
          ]),
        ]),
      );
      final visual = SizedBox(
        width: wide ? 390 : double.infinity,
        height: wide ? 370 : 230,
        child: Stack(alignment: Alignment.center, children: [
          Container(width: 245, height: 245, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x445E7865)))),
          Container(width: 175, height: 175, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x6685A18B)))),
          Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle, color: green.withValues(alpha: .25), border: Border.all(color: const Color(0x889AB6A2))), child: const Icon(Icons.center_focus_strong_outlined, color: Color(0xFFD8E3DB), size: 30)),
          Positioned(top: 35, right: 24, child: _heroNode('IMAGE', Icons.image_outlined)),
          Positioned(bottom: 35, left: 12, child: _heroNode('VISION AI', Icons.auto_awesome_outlined)),
          Positioned(bottom: 56, right: 5, child: _heroNode('EVIDENCE', Icons.fact_check_outlined)),
        ]),
      );
      return wide ? Row(children: [Expanded(child: copy), visual]) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [copy, visual]);
    }),
  ).animate().fadeIn(duration: 600.ms).slideY(begin: .05, end: 0);

  Widget _heroNode(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(color: const Color(0xDD151914), border: Border.all(color: const Color(0x446F8C76))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: const Color(0xFFA5B8AA)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Color(0xFFB5C2B9), fontSize: 7, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _processStrip() {
    const items = [('01','IMAGE','CAPTURE',Icons.image_outlined),('02','VISION','ANALYZE',Icons.center_focus_strong_outlined),('03','EVIDENCE','EXPLAIN',Icons.fact_check_outlined),('04','ACTION','NEXT CHECKS',Icons.arrow_forward_outlined)];
    return Row(children: items.asMap().entries.map((entry) {
      final i=entry.key; final item=entry.value;
      return Expanded(child: Container(height:82,padding:const EdgeInsets.symmetric(horizontal:14),decoration:BoxDecoration(color:i==3?dark:Colors.transparent,border:Border.all(color:AgriNDesign.line)),child:Row(children:[
        Text(item.$1,style:const TextStyle(fontSize:8,color:muted)),const SizedBox(width:10),Icon(item.$4,size:16,color:i==3?const Color(0xFFB7C8BC):green),const SizedBox(width:10),
        Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.$2,style:TextStyle(color:i==3?Colors.white:dark,fontSize:9,letterSpacing:1.1,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(item.$3,style:TextStyle(color:i==3?const Color(0xFF9EADA3):muted,fontSize:8))]))
      ]))).animate(delay:(80*i).ms).fadeIn(duration:400.ms).slideX(begin:.04,end:0);
    }).toList());
  }
  Widget _input() => Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .62), border: Border.all(color: AgriNDesign.line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('01 / SAMPLE CONTEXT', style: TextStyle(color: green,fontSize:9,letterSpacing:1.7,fontWeight:FontWeight.w800)), const SizedBox(height:10),
    Text('Tell us what we are looking at.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize:30,color:dark)), const SizedBox(height:20),
    TextField(controller: crop, decoration: _dec('Crop name', Icons.grass_rounded)).animate().fadeIn(delay: 100.ms, duration: 350.ms),
    const SizedBox(height: 14),
    TextField(controller: location, decoration: _dec('Location (optional)', Icons.location_on_outlined)).animate().fadeIn(delay: 160.ms, duration: 350.ms),
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

  Widget _photo() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: AgriNDesign.paper2.withValues(alpha: .55), border: Border.all(color: AgriNDesign.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('02 / VISUAL EVIDENCE', style: TextStyle(color: green,fontSize:9,letterSpacing:1.7,fontWeight:FontWeight.w800)),
      const SizedBox(height:10),
      Text(bytes == null ? 'Add a field image.' : 'Image ready for analysis.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize:30,color:dark)),
      const SizedBox(height:18),
      _imageViewport(),
    ]));

  Widget _imageViewport() {
    if (bytes == null) return Container(height:380,width:double.infinity,color:dark,child:const Center(child:Icon(Icons.image_search_outlined,color:Color(0xFF879C8D),size:48)));
    return SizedBox(height:380,width:double.infinity,child:Stack(fit:StackFit.expand,children:[
      Image.memory(bytes!,fit:BoxFit.cover),
      if(busy) Positioned.fill(child:AnimatedBuilder(animation:_scanController,builder:(_,__)=>CustomPaint(painter:_ScanPainter(_scanController.value)))),
      Positioned(top:12,left:12,child:Container(color:const Color(0xCC10130F),padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),child:Text(busy?'SCANNING':'IMAGE LOADED',style:const TextStyle(color:Color(0xFFD6E1D9),fontSize:8,letterSpacing:1.2,fontWeight:FontWeight.w800)))),
    ]));
  }

  Widget _result() => Container(
    width: double.infinity, padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.zero, boxShadow: const [BoxShadow(color: Color(0x33102D1B), blurRadius: 30, offset: Offset(0, 14))]),
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
  ).animate().fadeIn(duration: 600.ms).slideY(begin: .06, end: 0, curve: Curves.easeOutCubic);

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
    border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
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
    decoration: const BoxDecoration(color: Color(0xFFFFF1EC), border: Border(left: BorderSide(color: Colors.deepOrange, width: 3))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Colors.deepOrange), const SizedBox(width: 10),
      Expanded(child: Text(error!, style: const TextStyle(color: dark))),
    ]),
  );
}


class _HeroTag extends StatelessWidget {
  const _HeroTag(this.text);
  final String text;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(border:Border.all(color:const Color(0x445B765F))),child:Text(text,style:const TextStyle(color:Color(0xFFB5C5BA),fontSize:8,letterSpacing:1.4,fontWeight:FontWeight.w700)));
}

class _ScanPainter extends CustomPainter {
  const _ScanPainter(this.progress);
  final double progress;
  @override void paint(Canvas canvas,Size size){
    final y=size.height*progress;
    canvas.drawRect(Rect.fromLTWH(0,y-24,size.width,48),Paint()..color=const Color(0x149DB6A4));
    canvas.drawLine(Offset(0,y),Offset(size.width,y),Paint()..color=const Color(0xFFB8CCBE)..strokeWidth=2);
  }
  @override bool shouldRepaint(covariant _ScanPainter oldDelegate)=>oldDelegate.progress!=progress;
}
