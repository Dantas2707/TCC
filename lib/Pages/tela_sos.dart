// pages/tela_vitima_sos.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ✅ importe a CLASSE do serviço e use-a
import 'package:crud/services/firestore.dart'; // ajuste o caminho conforme seu projeto

class TelaVitimaSOS extends StatefulWidget {
  const TelaVitimaSOS({Key? key}) : super(key: key);

  @override
  State<TelaVitimaSOS> createState() => _TelaVitimaSOSState();
}

class _TelaVitimaSOSState extends State<TelaVitimaSOS> {
  final _fs = FirestoreService(); // 👈 instância do serviço
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  bool _loading = false;
  final _markers = <Marker>{};

  Future<void> _capturarLocalizacao() async {
    setState(() => _loading = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ative o GPS para continuar')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de localização negada')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão negada permanentemente. Ajuste nas configurações.'),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = latLng;
        _markers
          ..clear()
          ..add(
            Marker(
              markerId: const MarkerId('posicao_atual'),
              position: latLng,
              infoWindow: const InfoWindow(title: 'Minha localização'),
            ),
          );
      });

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: latLng, zoom: 16),
          ),
        );
      }

      await _registrarOcorrenciaSos(latLng);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocorrência registrada com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar localização: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registrarOcorrenciaSos(LatLng pos) async {
    await _fs.addOcorrencia(
      'Emergencial',
      'Alta',
      'Relato de emergência',
      'Texto de socorro',
      true,
      latitude: pos.latitude,
      longitude: pos.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _currentPosition ?? const LatLng(-15.793889, -47.882778); // Brasília

    return Scaffold(
      appBar: AppBar(title: const Text('SOS - Vítima'), backgroundColor: Colors.red),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _capturarLocalizacao,
                icon: const Icon(Icons.warning),
                label: _loading
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Acionar SOS'),
              ),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 12),
              onMapCreated: (c) => _mapController = c,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _markers,
              zoomControlsEnabled: false,
              compassEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}
