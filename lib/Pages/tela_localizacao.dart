import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; // Importando o pacote Geolocator

class GuardianMapPage extends StatefulWidget {
  const GuardianMapPage({Key? key}) : super(key: key);

  @override
  State<GuardianMapPage> createState() => _GuardianMapPageState();
}

class _GuardianMapPageState extends State<GuardianMapPage> {
  GoogleMapController? _map;
  final Set<Marker> _markers = {};
  bool _loading = true;
  String _statusText = 'Carregando…';

  // Subscrições
  StreamSubscription<QuerySnapshot>? _vinculosSub;
  final List<StreamSubscription<QuerySnapshot>> _ocorrenciasSubs = [];
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
      _ocorrenciasAbertas = {};

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions(); // Verifica as permissões de localização ao inicializar
    _listenVinculosAceitos(); // Manter o código existente para ouvir vínculos
  }

  @override
  void dispose() {
    _vinculosSub?.cancel();
    for (final s in _ocorrenciasSubs) {
      s.cancel();
    }
    _map?.dispose();
    super.dispose();
  }

  // Função para verificar e solicitar permissões de localização
  Future<void> _checkLocationPermissions() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permissão de localização negada.')),
      );
    } else if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Permissão de localização negada permanentemente.')),
      );
    } else {
      print('Permissão de localização concedida');
    }
  }

  void _listenVinculosAceitos() {
    final guardiaoUid = FirebaseAuth.instance.currentUser?.uid;
    if (guardiaoUid == null) {
      setState(() {
        _loading = false;
        _statusText = 'Não autenticado';
      });
      return;
    }

    // Log para ver o UID do guardião
    print('Guardião UID: $guardiaoUid');

    // Verificando se há documentos de vínculos para o guardião com status 'aceito'
    final vinculosRef = FirebaseFirestore.instance
        .collection('guardiões')
        .where('id_guardiao', isEqualTo: guardiaoUid)
        .where('status', isEqualTo: 'aceito');

    _vinculosSub = vinculosRef.snapshots().listen((snap) {
      if (snap.docs.isEmpty) {
        print('Nenhum vínculo encontrado para o guardião');
      }

      final victims = <String>[];
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final idUsuario = data['id_usuario']?.toString();
        if (idUsuario != null && idUsuario.isNotEmpty) {
          victims.add(idUsuario);
        }
      }

      // Log para ver as vítimas
      print('Vítimas protegidas pelo guardião: $victims');
      _subscribeToOcorrenciasAbertas(victims);
    }, onError: (_) {
      setState(() {
        _loading = false;
        _statusText = 'Falha ao carregar vínculos';
      });
    });
  }

  void _subscribeToOcorrenciasAbertas(List<String> victimIds) {
    // Cancela listeners antigos
    for (final s in _ocorrenciasSubs) {
      s.cancel();
    }
    _ocorrenciasSubs.clear();
    _ocorrenciasAbertas.clear();

    if (victimIds.isEmpty) {
      setState(() {
        _markers.clear();
        _loading = false;
        _statusText = 'Sem ocorrência SOS no momento';
      });
      return;
    }

    // Log para verificar as vítimas sendo processadas
    print('Vítimas para consulta: $victimIds');

    const chunkSize = 10;
    for (var i = 0; i < victimIds.length; i += chunkSize) {
      final bloco =
          victimIds.sublist(i, (i + chunkSize).clamp(0, victimIds.length));

      final q = FirebaseFirestore.instance
          .collection('ocorrencias')
          .where('ownerUid', whereIn: bloco)
          .where('status', isEqualTo: 'aberto');

      final sub = q.snapshots().listen((snap) {
        print(
            'Ocorrências abertas encontradas: ${snap.docs.length}'); // Log para ver quantas ocorrências foram encontradas
        for (final doc in snap.docs) {
          _ocorrenciasAbertas[doc.id] = doc;
        }

        _rebuildMarkersFromCache();
      }, onError: (_) {
        // opcional: logar erro do bloco
      });

      _ocorrenciasSubs.add(sub);
    }

    setState(() {
      _loading = false;
      _statusText = 'Carregando ocorrências…';
    });
  }

  void _rebuildMarkersFromCache() {
    final markers = <Marker>{};
    var count = 0;

    for (final doc in _ocorrenciasAbertas.values) {
      final data = doc.data();
      // posição pode estar em latitude/longitude separadas OU num GeoPoint 'localizacao'
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      GeoPoint? gp;
      if (lat == null || lng == null) {
        final maybe = data['localizacao'];
        if (maybe is GeoPoint) gp = maybe;
      }
      final hasCoords = (lat != null && lng != null) || gp != null;
      if (!hasCoords) continue;

      final pos =
          gp != null ? LatLng(gp.latitude, gp.longitude) : LatLng(lat!, lng!);

      final ownerUid = data['ownerUid']?.toString() ?? 'desconhecido';
      final tipo = data['tipoOcorrencia']?.toString() ?? 'SOS';
      final gravidade = data['gravidade']?.toString() ?? '';
      final relato = data['relato']?.toString() ?? '';

      markers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: pos,
          infoWindow: InfoWindow(
            title: '$tipo ${gravidade.isNotEmpty ? "($gravidade)" : ""}'.trim(),
            snippet: 'Vítima: $ownerUid\n$relato',
          ),
        ),
      );
      count++;
    }

    print(
        'Número de marcadores adicionados: $count'); // Log para verificar a quantidade de marcadores

    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
      _statusText =
          count == 0 ? 'Sem ocorrência SOS no momento' : 'SOS abertos: $count';
    });

    if (_map != null && markers.isNotEmpty) {
      _fitToMarkers(markers);
    }
  }

  Future<void> _fitToMarkers(Set<Marker> markers) async {
    if (_map == null) return;
    if (markers.length == 1) {
      final only = markers.first.position;
      await _map!.animateCamera(CameraUpdate.newLatLngZoom(only, 16));
      return;
    }
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final m in markers) {
      final p = m.position;
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  void _onMapCreated(GoogleMapController controller) {
    _map = controller;
    if (_markers.isNotEmpty) {
      _fitToMarkers(_markers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _markers.isNotEmpty
        ? _markers.first.position
        : const LatLng(-15.793889, -47.882778); // fallback: Brasília

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vítimas com SOS aberto'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color:
                _markers.isEmpty ? Colors.grey.shade300 : Colors.red.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              _loading ? 'Carregando…' : _statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _markers.isEmpty
                    ? Colors.grey.shade800
                    : Colors.red.shade800,
              ),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 12),
              onMapCreated: _onMapCreated,
              myLocationEnabled: false, // mapa do guardião
              myLocationButtonEnabled: false,
              markers: _markers,
              zoomControlsEnabled: true,
              compassEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}
