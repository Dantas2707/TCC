import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TelaLocalizacao extends StatefulWidget {
  const TelaLocalizacao({Key? key}) : super(key: key);

  @override
  _TelaLocalizacaoState createState() => _TelaLocalizacaoState();
}

class _TelaLocalizacaoState extends State<TelaLocalizacao> {
  late GoogleMapController mapController;
  Set<Marker> _markers = Set();
  LatLng? _vitimaPosition;

  // Função para atualizar a posição da vítima
  void _atualizarLocalizacaoVitima(LatLng novaPosicao) {
    setState(() {
      _vitimaPosition = novaPosicao;
      _markers.add(
        Marker(
          markerId: MarkerId('vitima'),
          position: _vitimaPosition!,
          infoWindow: InfoWindow(title: 'Vítima'),
        ),
      );
    });

    mapController.animateCamera(CameraUpdate.newLatLngZoom(_vitimaPosition!, 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Localização da Vítima'), backgroundColor: Colors.green),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              // Simulação de atualização de localização. Isso viria do backend em tempo real.
              // Aqui, você deve implementar a comunicação com o backend para receber a localização em tempo real.
              _atualizarLocalizacaoVitima(LatLng(37.42796133580664, -122.085749655962));
            },
            child: const Text('Atualizar Localização'),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _vitimaPosition ?? LatLng(0, 0), zoom: 16),
              onMapCreated: (controller) => mapController = controller,
              markers: _markers,
            ),
          ),
        ],
      ),
    );
  }
}
