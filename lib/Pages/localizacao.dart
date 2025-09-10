import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaOcorrenciaPage extends StatefulWidget {
  const MapaOcorrenciaPage({Key? key}) : super(key: key);

  @override
  State<MapaOcorrenciaPage> createState() => _MapaOcorrenciaPageState();
}

class _MapaOcorrenciaPageState extends State<MapaOcorrenciaPage> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = Set();
  bool _loading = false;

  /// Função para capturar a localização em tempo real
  Future<void> _capturarLocalizacao() async {
    setState(() => _loading = true);

    try {
      // Verifica se o serviço de localização está ativado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ative o GPS para continuar')),
        );
        setState(() => _loading = false);
        return;
      }

      // Verifica as permissões de localização
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de localização negada')),
          );
          setState(() => _loading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização negada permanentemente. Ative nas configurações.')),
        );
        setState(() => _loading = false);
        return;
      }

      // Obtém a posição atual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _markers.add(
          Marker(
            markerId: MarkerId('current_location'),
            position: _currentPosition!,
            infoWindow: InfoWindow(title: 'Sua Localização'),
          ),
        );
      });

      // Centraliza o mapa na nova localização
      if (_currentPosition != null) {
        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 16),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao capturar localização: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Callback quando o mapa é criado
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 16),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Inicia a captura da localização
    _capturarLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Localização em Tempo Real'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          // Botão para capturar localização em tempo real
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _capturarLocalizacao,
                icon: const Icon(Icons.my_location),
                label: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text('Capturar Localização em Tempo Real'),
              ),
            ),
          ),

          // Mapa
          Expanded(
            child: _currentPosition == null
                ? const Center(
                    child: Text(
                      'Clique no botão acima para capturar sua localização',
                      textAlign: TextAlign.center,
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition!,
                      zoom: 16,
                    ),
                    onMapCreated: _onMapCreated,
                    myLocationEnabled: true, // Ativa o ponto azul
                    myLocationButtonEnabled: true, // Exibe o botão para centralizar a localização
                    markers: _markers, // Adiciona o marcador da localização
                  ),
          ),
        ],
      ),
    );
  }
}
