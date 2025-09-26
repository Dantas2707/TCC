// pages/tela_vitima_sos.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// serviço com addOcorrencia, updateLocalizacaoSosAberto, encerrarSosAberto
import 'package:crud/services/firestore.dart';

class TelaVitimaSOS extends StatefulWidget {
  const TelaVitimaSOS({Key? key}) : super(key: key);

  @override
  State<TelaVitimaSOS> createState() => _TelaVitimaSOSState();
}

class _TelaVitimaSOSState extends State<TelaVitimaSOS> {
  final _fs = FirestoreService();

  bool _loading = false;
  bool _sosAtivo = false;

  StreamSubscription<QuerySnapshot>? _sosSub;

  // ✅ Fallback compatível com qualquer geolocator: atualiza a cada 5s via Timer
  Timer? _timer5s;

  @override
  void initState() {
    super.initState();
    _ouvirSosAtivo();
  }

  @override
  void dispose() {
    _sosSub?.cancel();
    _timer5s?.cancel();
    super.dispose();
  }

  /// Escuta em tempo real se existe uma ocorrência 'aberta' do usuário.
  void _ouvirSosAtivo() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _sosSub = FirebaseFirestore.instance
        .collection('ocorrencias')
        .where('ownerUid', isEqualTo: uid)
        .where('status', isEqualTo: 'aberto')
        .limit(1)
        .snapshots()
        .listen((snap) async {
      final ativo = snap.docs.isNotEmpty;

      if (mounted) setState(() => _sosAtivo = ativo);

      // liga/desliga o timer de atualização periódica
      if (ativo) {
        _iniciarAtualizacaoPeriodica();   // garante que está ligado
      } else {
        _timer5s?.cancel();
        _timer5s = null;
      }
    });
  }

  Future<void> _onToggleSOS() async {
    if (_sosAtivo) {
      // Finalizar
      setState(() => _loading = true);
      try {
        await _fs.encerrarSosAberto();
        _timer5s?.cancel();
        _timer5s = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ocorrência finalizada.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao finalizar: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    // Acionar
    setState(() => _loading = true);
    try {
      if (!await _garantirPermissaoLocalizacao()) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _fs.addOcorrencia(
        'Não relatado',
        'Gravíssima',
        'Não há',
        'Não há',
        true,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      // inicia atualização contínua (a cada ~5s) via Timer
      _iniciarAtualizacaoPeriodica();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS iniciado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao iniciar SOS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ Atualiza posição a cada 5s, sem usar intervalDuration
  void _iniciarAtualizacaoPeriodica() {
    _timer5s?.cancel();
    _timer5s = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _fs.updateLocalizacaoSosAberto(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      } catch (_) {
        // opcional: log/ignorar erros intermitentes
      }
    });
  }

  Future<bool> _garantirPermissaoLocalizacao() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ative o GPS para continuar')),
        );
      }
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização negada')),
        );
      }
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão negada permanentemente. Ajuste nas configurações.'),
          ),
        );
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final textoBotao = _sosAtivo ? 'Finalizar ocorrência' : 'Acionar SOS';
    final icone = _sosAtivo ? Icons.stop : Icons.warning;

    return Scaffold(
      appBar: AppBar(title: const Text('SOS - Vítima'), backgroundColor: Colors.red),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _loading ? null : _onToggleSOS,
              icon: Icon(icone),
              label: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(textoBotao),
            ),
          ),
        ),
      ),
    );
  }
}
