import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'auth_service.dart';

class SmartSpaceProvider extends ChangeNotifier {
  List<Zone> _zones = DefaultData.zones();
  List<Zone> get zones => _zones;

  final List<LogEvent> _logs = [];
  List<LogEvent> get logs => List.unmodifiable(_logs.reversed.toList());

  String? _currentZoneId;
  String? get currentZoneId => _currentZoneId;
  String? get uid => _uid;

  Zone? get currentZone => _currentZoneId != null
      ? _zones.firstWhere((z) => z.id == _currentZoneId, orElse: () => _zones.first)
      : null;

  bool _isConnected = true;
  bool get isConnected => _isConnected;
  bool get isAutonomous => !_isConnected;

  final Map<String, UserPreferences> _preferences = {};
  final List<Function()> _pendingCommands = [];
  Timer? _prefsLogTimer;

  // ── Guards de automação ────────────────────────────────────────────────────
  final Set<String> _activeHumAlerts  = {};
  final Set<String> _activeTempAlerts = {};

  // ── Último LightSettings calculado ────────────────────────────────────────
  final Map<String, LightSettings> _lastComputedLight = {};

  // ── IDs de polls já resolvidas — evita re-processar se Firebase atrasa ────
  final Set<String> _resolvedPollIds = {};

  DatabaseService? _db;
  String? _uid;
  AppUser? _appUser;
  StreamSubscription? _zonesSub;

  bool get isAdmin => _appUser?.role == UserRole.admin;

  void attachDatabase(DatabaseService db, String uid, AppUser? appUser) {
    _db = db;
    _uid = uid;
    _appUser = appUser;
    _currentZoneId = null;
    _listenZones();
    _listenConnection();
    _loadPreferences();
  }

  void _listenZones() {
    _zonesSub?.cancel();
    _zonesSub = _db!.zonesStream().listen((updates) {
      for (final update in updates) {
        _applyZoneUpdate(update);
      }
      for (final z in _zones) {
        _checkSensorAutomations(z.id);
        if (z.lightMode == LightMode.auto && z.presentUsers.isNotEmpty) {
          _recomputeAdaptiveLight(z.id);
        }
      }
      notifyListeners();
    }, onError: (e) => debugPrint('[SS] Erro ao ouvir zonas: $e'));
  }

  void _listenConnection() {
    _db!.addListener(() => setConnected(_db!.connected));
  }

  Future<void> _loadPreferences() async {
    if (_db == null || _uid == null) return;
    try {
      final prefs = await _db!.loadPreferences(_uid!);
      _preferences.addAll(prefs);
      notifyListeners();
    } catch (e) {
      debugPrint('[SS] Erro ao carregar preferências: $e');
    }
  }

  void _applyZoneUpdate(ZoneUpdate update) {
    final d = update.data;
    final safeCount = ((d['occupantCount'] as int?) ?? 0).clamp(0, 999);

    ZoneAutomations? automations;
    if (d['automations'] != null) {
      try {
        automations = ZoneAutomations.fromJson(
            Map<String, dynamic>.from(d['automations'] as Map));
      } catch (_) {}
    }

    ZonePoll? poll;
    if (d['activePoll'] != null) {
      try {
        poll = ZonePoll.fromJson(
            Map<String, dynamic>.from(d['activePoll'] as Map));

        // Ignorar polls expiradas ou já resolvidas localmente
        final pollId = '${poll.requestedBy}_${poll.expiresAt.millisecondsSinceEpoch}';
        if (poll.isExpired || _resolvedPollIds.contains(pollId)) {
          poll = null;
        } else {
          // ── BUG FIX: Opção A ──────────────────────────────────────────────
          // O device que resolveu a poll (ex: o user) já apagou o nó do Firebase,
          // mas este device (ex: o admin) pode receber um update intermédio com
          // todos os votos preenchidos mas antes do nó ser apagado.
          // Verificamos aqui se todos já votaram — se sim, marcamos como resolvida
          // localmente e descartamos a poll, sem esperar pelo próximo stream event.
          final presentUsers = d['presentUsers'] != null
              ? List<String>.from(
              (d['presentUsers'] as Map).keys.map((k) => k.toString()))
              : <String>[];
          final presentCount = presentUsers.length;
          final requesterInRoom = presentUsers.contains(poll.requestedBy);
          final totalExpected =
          requesterInRoom ? presentCount : presentCount + 1;
          final voted = poll.votes.length;

          if (totalExpected > 0 && voted >= totalExpected) {
            // Todos já votaram — esta poll já foi ou está prestes a ser resolvida
            // noutro device. Marcamos como resolvida aqui para não bloquear o admin.
            debugPrint(
                '[POLL][FIX] Todos votaram ($voted/$totalExpected) — descartando poll no _applyZoneUpdate');
            _markPollResolved(poll);

            // CRÍTICO: capturar poll numa variável local ANTES de a anular.
            // O closure do addPostFrameCallback captura a referência à variável
            // poll — se usarmos poll! depois de poll=null, o Dart lança null check
            // failed em runtime e _checkPollResult nunca é chamado no admin.
            final pollSnapshot = poll;
            poll = null; // anular ANTES do callback — banner desaparece imediatamente

            // Se este device é quem pediu a poll (admin remoto), resolve localmente
            // para aplicar o resultado (ex: mudar modo AUTO).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkPollResult(update.zoneId, pollSnapshot);
            });
          }
          // ── fim BUG FIX ───────────────────────────────────────────────────
        }
      } catch (_) {}
    }

    // Parse lightMode global
    LightMode lightMode = LightMode.auto;
    final lightModeStr = d['lightMode'] as String?;
    if (lightModeStr == 'manual') lightMode = LightMode.manual;

    _zones = _zones.map((z) {
      if (z.id != update.zoneId) return z;
      return z.copyWith(
        status: _parseStatus(d['status'] as String? ?? 'unknown'),
        occupantCount: safeCount,
        lightOn: d['lightOn'] as bool? ?? false,
        lightIntensity: (d['lightIntensity'] as num?)?.toDouble() ?? 1.0,
        lightR: (d['lightR'] as int?) ?? 255,
        lightG: (d['lightG'] as int?) ?? 255,
        lightB: (d['lightB'] as int?) ?? 255,
        buzzerOn: d['buzzerOn'] as bool? ?? false,
        luminosity: (d['luminosity'] as num?)?.toDouble(),
        temperature: (d['temperature'] as num?)?.toDouble(),
        humidity: (d['humidity'] as num?)?.toDouble(),
        motionDetected: d['motionDetected'] as bool?,
        presentUsers: d['presentUsers'] != null
            ? List<String>.from(
            (d['presentUsers'] as Map).keys.map((k) => k.toString()))
            : [],
        esp32Online: d['esp32Online'] as bool? ?? false,
        automations: automations,
        lightMode: lightMode,
        absoluteLocked: d['absoluteLocked'] as bool? ?? false,
        absoluteLockedBy: d['absoluteLockedBy'] as String?,
        activePoll: poll,
      );
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ALGORITMO LDR — só corre quando zona em AUTO
  // ══════════════════════════════════════════════════════════════════════════

  LightSettings computeAdaptiveLight(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null || z.presentUsers.isEmpty) return const LightSettings.off();

    final ldr = z.luminosity ?? 0.0;
    final threshold = z.automations.ldrThreshold;

    // Blend de preferências de todos os presentes
    final blended = _blendPreferences(z.presentUsers, zoneId);
    final intensity = blended.lightIntensity * max(0.0, 1.0 - (ldr / threshold));

    if (intensity <= 0.01) return const LightSettings.off();
    return LightSettings(
      on: true, intensity: intensity,
      r: blended.lightColor.red,
      g: blended.lightColor.green,
      b: blended.lightColor.blue,
    );
  }

  void _recomputeAdaptiveLight(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null || z.lightMode != LightMode.auto) return;

    final newSettings = computeAdaptiveLight(zoneId);
    final last = _lastComputedLight[zoneId];
    if (last == newSettings) return;

    _lastComputedLight[zoneId] = newSettings;
    _updateZone(zoneId, (z) => z.copyWith(
      lightOn: newSettings.on, lightIntensity: newSettings.intensity,
      lightR: newSettings.r, lightG: newSettings.g, lightB: newSettings.b,
    ));

    if (_isConnected) {
      _db?.updateZoneLight(zoneId, newSettings.on, newSettings.intensity,
          r: newSettings.r, g: newSettings.g, b: newSettings.b);
    } else {
      _pendingCommands.add(() => _db?.updateZoneLight(
          zoneId, newSettings.on, newSettings.intensity,
          r: newSettings.r, g: newSettings.g, b: newSettings.b));
    }
  }

  UserPreferences _blendPreferences(List<String> uids, String zoneId) {
    final prefs = uids
        .map((uid) => _preferences[uid] ?? UserPreferences(zoneId: zoneId))
        .toList();
    if (prefs.isEmpty) return UserPreferences(zoneId: zoneId);
    if (prefs.length == 1) return prefs.first;
    final r = prefs.map((p) => p.lightColor.red).reduce((a, b) => a + b) ~/ prefs.length;
    final g = prefs.map((p) => p.lightColor.green).reduce((a, b) => a + b) ~/ prefs.length;
    final b = prefs.map((p) => p.lightColor.blue).reduce((a, b) => a + b) ~/ prefs.length;
    final intensity = prefs.map((p) => p.lightIntensity).reduce((a, b) => a + b) / prefs.length;
    return UserPreferences(zoneId: zoneId)
      ..lightColor = Color.fromRGBO(r, g, b, 1.0)
      ..lightIntensity = intensity;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SISTEMA DE POLL — lógica central
  // ══════════════════════════════════════════════════════════════════════════

  // Decide se precisa de poll ou age diretamente
  // Retorna true se agiu direto, false se abriu poll
  Future<bool> _requestAction({
    required String zoneId,
    required String action,
    double? intensity,
    int? r, int? g, int? b,
    bool? lightState,
    LightMode? targetMode,
  }) async {
    if (_uid == null) return false;
    final z = zoneById(zoneId);
    if (z == null) return false;

    // Bloquear nova poll se já há uma ativa
    if (z.activePoll != null && !z.activePoll!.isExpired) {
      debugPrint('[SS] Poll já ativa — ignorando nova acção $action');
      return false;
    }

    // ABSOLUTE → age direto sempre
    if (z.absoluteLocked && z.absoluteLockedBy == _uid) {
      await _applyAction(zoneId, action,
          intensity: intensity, r: r, g: g, b: b,
          lightState: lightState, targetMode: targetMode);
      return true;
    }

    // Sala vazia → age direto
    if (z.presentUsers.isEmpty) {
      await _applyAction(zoneId, action,
          intensity: intensity, r: r, g: g, b: b,
          lightState: lightState, targetMode: targetMode);
      return true;
    }

    // 1 pessoa na sala e é o próprio → age direto
    if (z.presentUsers.length == 1 && z.presentUsers.contains(_uid)) {
      await _applyAction(zoneId, action,
          intensity: intensity, r: r, g: g, b: b,
          lightState: lightState, targetMode: targetMode);
      return true;
    }

    // Todos os outros casos → poll
    await _openPoll(
      zoneId: zoneId, action: action,
      intensity: intensity, r: r, g: g, b: b,
      lightState: lightState, targetMode: targetMode,
    );
    return false;
  }

  Future<void> _openPoll({
    required String zoneId,
    required String action,
    double? intensity,
    int? r, int? g, int? b,
    bool? lightState,
    LightMode? targetMode,
  }) async {
    if (_uid == null) return;

    final poll = ZonePoll(
      requestedBy: _uid!,
      requestedByName: _displayName,
      action: action,
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      votes: {_uid!: true}, // quem pediu vota sim automaticamente
      intensity: intensity,
      r: r, g: g, b: b,
      lightState: lightState,
    );

    _updateZone(zoneId, (z) => z.copyWith(activePoll: poll));
    if (_isConnected) {
      await _db?.openPoll(zoneId, poll);
    } else {
      _pendingCommands.add(() => _db?.openPoll(zoneId, poll));
    }

    // Timer de expiração
    Timer(const Duration(seconds: 31), () => _expirePoll(zoneId));

    _log(LogEvent(
      id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
      message: '$_displayName pediu: ${_pollActionLabel(action, intensity: intensity)}',
      userName: _displayName, userRole: _appUser?.role.name ?? 'user', uid: _uid ?? '',
    ));

    notifyListeners();
  }

  // Aplica a ação efectivamente
  Future<void> _applyAction(String zoneId, String action, {
    double? intensity, int? r, int? g, int? b,
    bool? lightState, LightMode? targetMode,
  }) async {
    final z = zoneById(zoneId);
    if (z == null) return;

    switch (action) {
      case 'lightOff':
        _updateZone(zoneId, (z) => z.copyWith(lightOn: false));
        if (_isConnected) await _db?.updateZoneLight(zoneId, false, z.lightIntensity, r: z.lightR, g: z.lightG, b: z.lightB);
        else _pendingCommands.add(() => _db?.updateZoneLight(zoneId, false, z.lightIntensity, r: z.lightR, g: z.lightG, b: z.lightB));
        break;

      case 'lightOn':
        _updateZone(zoneId, (z) => z.copyWith(lightOn: true));
        if (_isConnected) await _db?.updateZoneLight(zoneId, true, z.lightIntensity, r: z.lightR, g: z.lightG, b: z.lightB);
        else _pendingCommands.add(() => _db?.updateZoneLight(zoneId, true, z.lightIntensity, r: z.lightR, g: z.lightG, b: z.lightB));
        break;

      case 'setIntensity':
        if (intensity == null) return;
        // Passa a MANUAL ao alterar intensidade
        _updateZone(zoneId, (z) => z.copyWith(lightIntensity: intensity, lightMode: LightMode.manual));
        if (_isConnected) {
          await _db?.updateZoneLight(zoneId, z.lightOn, intensity, r: z.lightR, g: z.lightG, b: z.lightB);
          await _db?.updateZoneLightMode(zoneId, LightMode.manual);
        } else {
          _pendingCommands.add(() => _db?.updateZoneLight(zoneId, z.lightOn, intensity, r: z.lightR, g: z.lightG, b: z.lightB));
          _pendingCommands.add(() => _db?.updateZoneLightMode(zoneId, LightMode.manual));
        }
        _lastComputedLight.remove(zoneId);
        break;

      case 'setColor':
        if (r == null || g == null || b == null) return;
        // Cor muda para MANUAL
        _updateZone(zoneId, (z) => z.copyWith(lightR: r, lightG: g, lightB: b, lightMode: LightMode.manual));
        if (_isConnected) {
          await _db?.updateZoneLight(zoneId, z.lightOn, z.lightIntensity, r: r, g: g, b: b);
          await _db?.updateZoneLightMode(zoneId, LightMode.manual);
        } else {
          _pendingCommands.add(() => _db?.updateZoneLight(zoneId, z.lightOn, z.lightIntensity, r: r, g: g, b: b));
          _pendingCommands.add(() => _db?.updateZoneLightMode(zoneId, LightMode.manual));
        }
        _lastComputedLight.remove(zoneId);
        break;

      case 'setModeAuto':
        _updateZone(zoneId, (z) => z.copyWith(lightMode: LightMode.auto));
        _lastComputedLight.remove(zoneId);
        if (_isConnected) await _db?.updateZoneLightMode(zoneId, LightMode.auto);
        else _pendingCommands.add(() => _db?.updateZoneLightMode(zoneId, LightMode.auto));
        _recomputeAdaptiveLight(zoneId);
        break;

      case 'setModeManual':
        _updateZone(zoneId, (z) => z.copyWith(lightMode: LightMode.manual));
        _lastComputedLight.remove(zoneId);
        if (_isConnected) await _db?.updateZoneLightMode(zoneId, LightMode.manual);
        else _pendingCommands.add(() => _db?.updateZoneLightMode(zoneId, LightMode.manual));
        break;

      case 'applyPrefs':
      // Aplica preferências: intensidade + cor + passa a MANUAL
        if (intensity != null) {
          _updateZone(zoneId, (z) => z.copyWith(lightIntensity: intensity, lightMode: LightMode.manual));
          if (_isConnected) {
            await _db?.updateZoneLight(zoneId, true, intensity,
                r: r ?? z.lightR, g: g ?? z.lightG, b: b ?? z.lightB);
            await _db?.updateZoneLightMode(zoneId, LightMode.manual);
          } else {
            _pendingCommands.add(() => _db?.updateZoneLight(zoneId, true, intensity,
                r: r ?? z.lightR, g: g ?? z.lightG, b: b ?? z.lightB));
            _pendingCommands.add(() => _db?.updateZoneLightMode(zoneId, LightMode.manual));
          }
        }
        if (r != null && g != null && b != null) {
          _updateZone(zoneId, (z) => z.copyWith(lightR: r, lightG: g, lightB: b));
        }
        _lastComputedLight.remove(zoneId);
        break;
    }

    _log(LogEvent(
      id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
      message: '$_displayName aplicou: ${_pollActionLabel(action, intensity: intensity)}',
      userName: _displayName, userRole: _appUser?.role.name ?? 'user', uid: _uid ?? '',
    ));

    notifyListeners();
  }

  // Aplica resultado negociado — média de TODOS os valores (sim usa pedido, não usa contra-proposta)
  Future<void> _applyNegotiatedResult(String zoneId, ZonePoll poll) async {
    final z = zoneById(zoneId);
    if (z == null) return;

    if (poll.action == 'setIntensity') {
      // Recolhe todos os valores: yes → valor pedido, no → contra-proposta
      final values = <double>[];
      for (final entry in poll.votes.entries) {
        if (entry.value) {
          // Votou sim → usa o valor pedido
          values.add(poll.intensity ?? z.lightIntensity);
        } else {
          // Votou não → usa a contra-proposta se existir, senão usa valor atual
          values.add(poll.counterProposals[entry.key] ?? z.lightIntensity);
        }
      }
      if (values.isEmpty) return;
      final avg = values.reduce((a, b) => a + b) / values.length;
      debugPrint('[POLL] Intensidade negociada: ${values.map((v) => "${(v*100).toInt()}%").join(", ")} → avg=${(avg*100).toInt()}%');
      await _applyAction(zoneId, 'setIntensity', intensity: avg);

    } else if (poll.action == 'setColor') {
      // Recolhe todos os valores RGB
      int sumR = 0, sumG = 0, sumB = 0;
      int count = 0;
      for (final entry in poll.votes.entries) {
        if (entry.value) {
          sumR += poll.r ?? z.lightR;
          sumG += poll.g ?? z.lightG;
          sumB += poll.b ?? z.lightB;
        } else {
          final cp = poll.colorCounterProposals[entry.key];
          sumR += cp?[0] ?? z.lightR;
          sumG += cp?[1] ?? z.lightG;
          sumB += cp?[2] ?? z.lightB;
        }
        count++;
      }
      if (count == 0) return;
      final avgR = (sumR / count).round();
      final avgG = (sumG / count).round();
      final avgB = (sumB / count).round();
      debugPrint('[POLL] Cor negociada: R:$avgR G:$avgG B:$avgB');
      await _applyAction(zoneId, 'setColor', r: avgR, g: avgG, b: avgB);
    }
  }

  // Aplica resultado de empate — médias
  Future<void> _applyTieResult(String zoneId, ZonePoll poll) async {
    final z = zoneById(zoneId);
    if (z == null) return;

    switch (poll.action) {
      case 'lightOff':
      case 'lightOn':
      // Empate → mantém estado actual
        _log(LogEvent(
          id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
          message: 'Empate na votação — estado da luz mantido na ${z.name}',
          userName: 'Sistema', userRole: 'system', uid: _uid ?? '',
        ));
        break;

      case 'setIntensity':
        if (poll.intensity == null) return;
        // Média entre intensidade pedida e actual
        final avgIntensity = (poll.intensity! + z.lightIntensity) / 2;
        await _applyAction(zoneId, 'setIntensity', intensity: avgIntensity);
        _log(LogEvent(
          id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
          message: 'Empate: intensidade média aplicada (${(avgIntensity * 100).toInt()}%) na ${z.name}',
          userName: 'Sistema', userRole: 'system', uid: _uid ?? '',
        ));
        break;

      case 'setColor':
        if (poll.r == null || poll.g == null || poll.b == null) return;
        // Média RGB entre cor pedida e actual
        final avgR = ((poll.r! + z.lightR) / 2).toInt();
        final avgG = ((poll.g! + z.lightG) / 2).toInt();
        final avgB = ((poll.b! + z.lightB) / 2).toInt();
        await _applyAction(zoneId, 'setColor', r: avgR, g: avgG, b: avgB);
        _log(LogEvent(
          id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
          message: 'Empate: cor média aplicada (R:$avgR G:$avgG B:$avgB) na ${z.name}',
          userName: 'Sistema', userRole: 'system', uid: _uid ?? '',
        ));
        break;

      case 'setModeAuto':
      case 'setModeManual':
      // Empate de modo → mantém modo actual
        _log(LogEvent(
          id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
          message: 'Empate: modo mantido na ${z.name}',
          userName: 'Sistema', userRole: 'system', uid: _uid ?? '',
        ));
        break;
    }
  }

  // ── Votar numa poll ───────────────────────────────────────────────────────
  Future<void> votePoll(String zoneId, bool vote) async {
    if (_uid == null) return;
    final z = zoneById(zoneId);
    if (z == null || z.activePoll == null) return;

    final poll = z.activePoll!;
    if (poll.isExpired) return;
    if (poll.votes.containsKey(_uid)) return; // já votou

    final newVotes = Map<String, bool>.from(poll.votes)..[_uid!] = vote;
    final updatedPoll = ZonePoll(
      requestedBy: poll.requestedBy, requestedByName: poll.requestedByName,
      action: poll.action, expiresAt: poll.expiresAt, votes: newVotes,
      intensity: poll.intensity, r: poll.r, g: poll.g, b: poll.b,
      lightState: poll.lightState,
    );

    _updateZone(zoneId, (z) => z.copyWith(activePoll: updatedPoll));
    if (_isConnected) await _db?.votePoll(zoneId, _uid!, vote);
    else _pendingCommands.add(() => _db?.votePoll(zoneId, _uid!, vote));

    // Verificar resultado
    await _checkPollResult(zoneId, updatedPoll);
    notifyListeners();
  }

  void _markPollResolved(ZonePoll poll) {
    final pollId = '${poll.requestedBy}_${poll.expiresAt.millisecondsSinceEpoch}';
    _resolvedPollIds.add(pollId);
    // Limpa IDs antigos para não crescer indefinidamente (guarda só os últimos 20)
    if (_resolvedPollIds.length > 20) _resolvedPollIds.clear();
    debugPrint('[POLL] Marcada como resolvida: $pollId');
  }

  Future<void> _checkPollResult(String zoneId, ZonePoll poll) async {
    final z = zoneById(zoneId);
    if (z == null) return;

    // Total de voters esperados = presentes na sala + o requester (se não estiver na sala)
    final presentCount = z.presentUsers.length;
    final requesterInRoom = z.presentUsers.contains(poll.requestedBy);
    // Se o requester (admin) não está na sala, ele já votou automaticamente (sim)
    // O total esperado é: pessoas na sala + (1 se requester fora da sala)
    final totalExpected = requesterInRoom ? presentCount : presentCount + 1;

    final yes   = poll.votes.values.where((v) =>  v).length;
    final no    = poll.votes.values.where((v) => !v).length;
    final voted = poll.votes.length;

    debugPrint('[POLL] $zoneId: $yes sim / $no não / $voted votaram / $totalExpected esperados');

    // Ainda não votaram todos — aguarda
    if (voted < totalExpected) return;

    // Todos votaram — determina resultado
    if (yes > no) {
      // Maioria sim → aplica diretamente
      await _applyAction(zoneId, poll.action,
          intensity: poll.intensity, r: poll.r, g: poll.g, b: poll.b,
          lightState: poll.lightState);
      _log(LogEvent(
        id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
        message: 'Votação aprovada ($yes/$totalExpected): ${_pollActionLabel(poll.action, intensity: poll.intensity)}',
        userName: 'Sistema', userRole: 'system', uid: _uid ?? '',
      ));
      _markPollResolved(poll);
      await _db?.closePoll(zoneId);
      _updateZone(zoneId, (z) => z.copyWith(clearPoll: true));

    } else if (no > yes) {
      // Maioria não → para intensidade/cor aguarda contra-propostas
      if ((poll.action == 'setIntensity' || poll.action == 'setColor') &&
          poll.counterProposals.length < no &&
          poll.colorCounterProposals.length < no) {
        // Ainda faltam contra-propostas — a UI vai pedi-las, não fechamos
        debugPrint('[POLL] Aguardando contra-propostas ($no nãos)');
        return;
      }
      // Tem todas as contra-propostas → calcula resultado negociado
      if (poll.action == 'setIntensity' || poll.action == 'setColor') {
        await _applyNegotiatedResult(zoneId, poll);
        _log(LogEvent(
          id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
          message: 'Resultado negociado aplicado na ${z.name}',
          userName: 'Sistema', userRole: 'system', uid: _uid ?? '',
        ));
      } else {
        // Ações binárias (ligar/desligar, mudar modo) rejeitadas → mantém
        _log(LogEvent(
          id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
          message: 'Votação rejeitada ($yes sim / $no não): ${_pollActionLabel(poll.action, intensity: poll.intensity)}',
          userName: 'Sistema', userRole: 'system', uid: _uid ?? '',
        ));
      }
      _markPollResolved(poll);
      await _db?.closePoll(zoneId);
      _updateZone(zoneId, (z) => z.copyWith(clearPoll: true));

    } else {
      // Empate exato
      await _applyTieResult(zoneId, poll);
      _markPollResolved(poll);
      await _db?.closePoll(zoneId);
      _updateZone(zoneId, (z) => z.copyWith(clearPoll: true));
    }
  }

  void _expirePoll(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null || z.activePoll == null) return; // já foi resolvida entretanto

    final poll = z.activePoll!;
    final yes = poll.votes.values.where((v) =>  v).length;
    final no  = poll.votes.values.where((v) => !v).length;
    final total = z.presentUsers.length;

    if (yes > no) {
      // Mais sins → aplica
      _applyAction(zoneId, poll.action,
          intensity: poll.intensity, r: poll.r, g: poll.g, b: poll.b);
    } else if (no > yes && (poll.action == 'setIntensity' || poll.action == 'setColor')) {
      // Mais nãos em intensidade/cor → negocia com o que existe
      _applyNegotiatedResult(zoneId, poll);
    } else if (yes == no && yes > 0) {
      // Empate → regra de empate
      _applyTieResult(zoneId, poll);
    }
    // Se mais nãos em ação binária ou ninguém votou → mantém estado

    _markPollResolved(poll);
    _db?.closePoll(zoneId);
    _updateZone(zoneId, (z) => z.copyWith(clearPoll: true));
    _log(LogEvent(
      id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
      message: 'Votação expirou ($yes sim / $no não de $total) na ${zoneById(zoneId)?.name ?? zoneId}',
      userName: 'Sistema', userRole: 'system', uid: _uid ?? '',
    ));
    notifyListeners();
  }

  /// Submete uma contra-proposta de um voter que votou "não"
  /// Para intensidade: value = nova intensidade preferida
  /// Para cor: r, g, b = nova cor preferida
  Future<void> submitCounterProposal(String zoneId, {double? intensity, int? r, int? g, int? b}) async {
    if (_uid == null) return;
    final z = zoneById(zoneId);
    if (z == null || z.activePoll == null) return;
    final poll = z.activePoll!;

    // Verifica que este user votou não
    if (poll.votes[_uid] != false) return;

    // Atualiza a poll localmente com a contra-proposta
    ZonePoll updatedPoll;
    if (poll.action == 'setIntensity' && intensity != null) {
      final newProposals = Map<String, double>.from(poll.counterProposals)..[_uid!] = intensity;
      updatedPoll = poll.copyWith(counterProposals: newProposals);
    } else if (poll.action == 'setColor' && r != null && g != null && b != null) {
      final newColorProposals = Map<String, List<int>>.from(poll.colorCounterProposals)..[_uid!] = [r, g, b];
      updatedPoll = poll.copyWith(colorCounterProposals: newColorProposals);
    } else {
      return;
    }

    _updateZone(zoneId, (z) => z.copyWith(activePoll: updatedPoll));
    if (_isConnected) await _db?.submitCounterProposal(zoneId, _uid!, intensity: intensity, r: r, g: g, b: b);
    else _pendingCommands.add(() => _db?.submitCounterProposal(zoneId, _uid!, intensity: intensity, r: r, g: g, b: b));

    // Re-verifica se podemos resolver agora
    await _checkPollResult(zoneId, updatedPoll);
    notifyListeners();
  }

  String _pollActionLabel(String action, {double? intensity}) {
    switch (action) {
      case 'lightOff':     return 'desligar luz';
      case 'lightOn':      return 'ligar luz';
      case 'setIntensity': return 'intensidade ${intensity != null ? "${(intensity * 100).toInt()}%" : ""}';
      case 'setColor':     return 'mudar cor';
      case 'setModeAuto':  return 'modo AUTO';
      case 'setModeManual':return 'modo MANUAL';
      case 'applyPrefs':   return 'aplicar preferências pessoais';
      default:             return action;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA — comandos com poll automático
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> toggleLight(String zoneId) async {
    final z = zoneById(zoneId);
    if (z == null) return;
    if (z.isAbsoluteLocked && z.absoluteLockedBy != _uid) return;
    await _requestAction(
      zoneId: zoneId,
      action: z.lightOn ? 'lightOff' : 'lightOn',
    );
  }

  Future<void> setLightIntensity(String zoneId, double value) async {
    final z = zoneById(zoneId);
    if (z == null) return;
    if (z.isAbsoluteLocked && z.absoluteLockedBy != _uid) return;
    await _requestAction(
      zoneId: zoneId,
      action: 'setIntensity',
      intensity: value,
    );
  }

  Future<void> setLightColor(String zoneId, Color color) async {
    final z = zoneById(zoneId);
    if (z == null) return;
    if (z.isAbsoluteLocked && z.absoluteLockedBy != _uid) return;

    // Em AUTO → guarda nas preferências da sessão, não abre poll (cor em AUTO é pessoal)
    if (z.lightMode == LightMode.auto && _uid != null) {
      final currentPrefs = _preferences[zoneId] ?? UserPreferences(zoneId: zoneId);
      _preferences[zoneId] = currentPrefs.copyWith(lightColor: color);
      _lastComputedLight.remove(zoneId);
      _recomputeAdaptiveLight(zoneId);
      notifyListeners();
      return;
    }

    // Em MANUAL → poll
    await _requestAction(
      zoneId: zoneId,
      action: 'setColor',
      r: color.red, g: color.green, b: color.blue,
    );
  }

  Future<void> setZoneLightMode(String zoneId, LightMode mode) async {
    final z = zoneById(zoneId);
    if (z == null) return;
    if (z.isAbsoluteLocked && z.absoluteLockedBy != _uid) return;
    if (z.lightMode == mode) return; // já está no modo pedido

    await _requestAction(
      zoneId: zoneId,
      action: mode == LightMode.auto ? 'setModeAuto' : 'setModeManual',
    );
  }

  // Modo ABSOLUTE — só admin
  Future<void> setAbsoluteMode(String zoneId, bool active) async {
    if (_uid == null || !isAdmin) return;

    _updateZone(zoneId, (z) => z.copyWith(
      absoluteLocked: active,
      absoluteLockedBy: active ? _uid : null,
      clearAbsolute: !active,
    ));

    if (_isConnected) {
      await _db?.updateZoneAbsoluteMode(zoneId, active, active ? _uid : null);
    } else {
      _pendingCommands.add(() => _db?.updateZoneAbsoluteMode(zoneId, active, active ? _uid : null));
    }

    if (!active) {
      _lastComputedLight.remove(zoneId);
      final z = zoneById(zoneId);
      if (z?.lightMode == LightMode.auto) _recomputeAdaptiveLight(zoneId);
    }

    _log(LogEvent(
      id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
      message: '$_displayName ${active ? "ativou" : "desativou"} o modo ABSOLUTO na ${zoneById(zoneId)?.name ?? zoneId}',
      userName: _displayName, userRole: 'admin', uid: _uid ?? '',
    ));
    notifyListeners();
  }

  void toggleBuzzer(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    final newState = !z.buzzerOn;
    _updateZone(zoneId, (z) => z.copyWith(buzzerOn: newState));
    if (_isConnected) _db?.updateZoneBuzzer(zoneId, newState);
    else _pendingCommands.add(() => _db?.updateZoneBuzzer(zoneId, newState));
    _log(LogEvent(
      id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
      message: '$_displayName ${newState ? "ligou" : "desligou"} o buzzer na ${z.name}',
      userName: _displayName, userRole: _appUser?.role.name ?? 'user', uid: _uid ?? '',
    ));
    notifyListeners();
  }

  void injectSensorData(String zoneId,
      {double? luminosity, double? temperature, double? humidity, bool? motion}) {
    _updateZone(zoneId, (z) => z.copyWith(
      luminosity: luminosity ?? z.luminosity,
      temperature: temperature ?? z.temperature,
      humidity: humidity ?? z.humidity,
      motionDetected: motion ?? z.motionDetected,
    ));
    if (_isConnected) {
      _db?.updateZoneSensors(zoneId,
          luminosity: luminosity, temperature: temperature,
          humidity: humidity, motionDetected: motion);
    } else {
      _pendingCommands.add(() => _db?.updateZoneSensors(zoneId,
          luminosity: luminosity, temperature: temperature,
          humidity: humidity, motionDetected: motion));
    }
    _checkSensorAutomations(zoneId);
    final z = zoneById(zoneId);
    if (z?.lightMode == LightMode.auto && (z?.presentUsers.isNotEmpty ?? false)) {
      _recomputeAdaptiveLight(zoneId);
    }
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTOMAÇÕES SENSOR (temp/hum → buzzer)
  // ══════════════════════════════════════════════════════════════════════════

  void _checkSensorAutomations(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    final a = z.automations;

    if (a.autoTempEnabled && z.temperature != null) {
      final alert = z.temperature! > a.tempThreshold;
      final was = _activeTempAlerts.contains(zoneId);
      if (alert && !was) {
        _activeTempAlerts.add(zoneId);
        _updateZone(zoneId, (z) => z.copyWith(buzzerOn: true));
        if (_isConnected) _db?.updateZoneBuzzer(zoneId, true);
        else _pendingCommands.add(() => _db?.updateZoneBuzzer(zoneId, true));
        _log(LogEvent(id: _uid_(), type: LogEventType.automationTrigger, zoneId: zoneId,
            message: 'Alerta: temperatura ${z.temperature!.toStringAsFixed(1)}°C > ${a.tempThreshold.toStringAsFixed(0)}°C',
            userName: 'Sistema', userRole: 'system', uid: _uid ?? ''));
      } else if (!alert && was) {
        _activeTempAlerts.remove(zoneId);
        if (!_activeHumAlerts.contains(zoneId)) {
          _updateZone(zoneId, (z) => z.copyWith(buzzerOn: false));
          if (_isConnected) _db?.updateZoneBuzzer(zoneId, false);
          else _pendingCommands.add(() => _db?.updateZoneBuzzer(zoneId, false));
        }
      }
    }

    if (a.autoHumEnabled && z.humidity != null) {
      final alert = z.humidity! > a.humThreshold;
      final was = _activeHumAlerts.contains(zoneId);
      if (alert && !was) {
        _activeHumAlerts.add(zoneId);
        _updateZone(zoneId, (z) => z.copyWith(buzzerOn: true));
        if (_isConnected) _db?.updateZoneBuzzer(zoneId, true);
        else _pendingCommands.add(() => _db?.updateZoneBuzzer(zoneId, true));
        _log(LogEvent(id: _uid_(), type: LogEventType.automationTrigger, zoneId: zoneId,
            message: 'Alerta: humidade ${z.humidity!.toStringAsFixed(0)}% > ${a.humThreshold.toStringAsFixed(0)}%',
            userName: 'Sistema', userRole: 'system', uid: _uid ?? ''));
      } else if (!alert && was) {
        _activeHumAlerts.remove(zoneId);
        if (!_activeTempAlerts.contains(zoneId)) {
          _updateZone(zoneId, (z) => z.copyWith(buzzerOn: false));
          if (_isConnected) _db?.updateZoneBuzzer(zoneId, false);
          else _pendingCommands.add(() => _db?.updateZoneBuzzer(zoneId, false));
        }
      }
    }
  }

  Future<void> updateAutomations(String zoneId, ZoneAutomations automations) async {
    _updateZone(zoneId, (z) => z.copyWith(automations: automations));
    if (_isConnected) await _db?.updateZoneAutomations(zoneId, automations);
    else _pendingCommands.add(() => _db?.updateZoneAutomations(zoneId, automations));
    _log(LogEvent(id: _uid_(), type: LogEventType.manualCommand, zoneId: zoneId,
        message: '$_displayName atualizou limiares de automação na ${zoneById(zoneId)?.name ?? zoneId}',
        userName: _displayName, userRole: _appUser?.role.name ?? 'user', uid: _uid ?? ''));
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ENTRADA / SAÍDA
  // ══════════════════════════════════════════════════════════════════════════

  void updateZoneFromBeacon(String? zoneId) {
    if (zoneId == _currentZoneId) return;
    if (_uid == null) return;

    final prev = _currentZoneId;
    _currentZoneId = zoneId;

    if (prev != null) {
      _lastComputedLight.remove(prev);
      final z = zoneById(prev);
      if (z != null && z.absoluteLocked && z.absoluteLockedBy == _uid) {
        setAbsoluteMode(prev, false);
      }
      if (_isConnected) {
        _db?.removeUserFromZoneAtomic(_uid!, prev);
        _db?.updateUserZone(_uid!, zoneId);
      } else {
        _pendingCommands.add(() => _db?.removeUserFromZoneAtomic(_uid!, prev));
        _pendingCommands.add(() => _db?.updateUserZone(_uid!, zoneId));
      }
      _log(LogEvent(id: _uid_(), type: LogEventType.zoneExit, zoneId: prev,
          message: '$_displayName saiu da ${zoneById(prev)?.name ?? prev}',
          userName: _displayName, userRole: _appUser?.role.name ?? 'user', uid: _uid ?? ''));
    }

    if (zoneId != null) {
      if (_isConnected) {
        _db?.addUserToZoneAtomic(_uid!, zoneId);
        if (prev == null) _db?.updateUserZone(_uid!, zoneId);
      } else {
        _pendingCommands.add(() => _db?.addUserToZoneAtomic(_uid!, zoneId));
        if (prev == null) _pendingCommands.add(() => _db?.updateUserZone(_uid!, zoneId));
      }
      _log(LogEvent(id: _uid_(), type: LogEventType.zoneEntry, zoneId: zoneId,
          message: '$_displayName entrou na ${zoneById(zoneId)?.name ?? zoneId}',
          userName: _displayName, userRole: _appUser?.role.name ?? 'user', uid: _uid ?? ''));

      // Aplica preferências ao entrar
      _applyPreferencesOnEntry(zoneId);
    }

    notifyListeners();
  }

  void _applyPreferencesOnEntry(String zoneId) {
    final z = zoneById(zoneId);
    if (z == null) return;
    final prefs = _preferences[zoneId];
    if (prefs == null || !prefs.enabled) return;

    // Com mais pessoas presentes → pede votação para aplicar preferências
    // (exclui o próprio que acabou de entrar dos "presentes" para o check)
    final othersPresent = z.presentUsers.where((u) => u != _uid).toList();
    if (othersPresent.isNotEmpty) {
      // Abre poll para aplicar as preferências
      _openPoll(
        zoneId: zoneId,
        action: 'applyPrefs',
        intensity: prefs.lightIntensity,
        r: prefs.lightColor.red,
        g: prefs.lightColor.green,
        b: prefs.lightColor.blue,
      );
      return;
    }

    // Sozinho → aplica direto
    _applyAction(zoneId, 'setIntensity', intensity: prefs.lightIntensity);
    _applyAction(zoneId, 'setColor',
        r: prefs.lightColor.red, g: prefs.lightColor.green, b: prefs.lightColor.blue);

    _log(LogEvent(id: _uid_(), type: LogEventType.automationTrigger, zoneId: zoneId,
        message: 'Preferências de $_displayName aplicadas na ${z.name} (MANUAL)',
        userName: _displayName, userRole: _appUser?.role.name ?? 'user', uid: _uid ?? ''));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PREFERÊNCIAS
  // ══════════════════════════════════════════════════════════════════════════

  UserPreferences preferencesFor(String zoneId) =>
      _preferences[zoneId] ?? UserPreferences(zoneId: zoneId);

  void updatePreferences(UserPreferences prefs) {
    _preferences[prefs.zoneId] = prefs;
    if (_db != null && _uid != null) _db!.savePreferences(_uid!, prefs);
    _prefsLogTimer?.cancel();
    _prefsLogTimer = Timer(const Duration(seconds: 1), () {
      _log(LogEvent(id: _uid_(), type: LogEventType.manualCommand, zoneId: prefs.zoneId,
          message: '$_displayName atualizou preferências na ${zoneById(prefs.zoneId)?.name ?? prefs.zoneId}',
          userName: _displayName, userRole: _appUser?.role.name ?? 'user', uid: _uid ?? ''));
      notifyListeners();
    });
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITÁRIOS
  // ══════════════════════════════════════════════════════════════════════════

  void reevaluateEsp32Status() {
    if (_db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;
    _zones = _zones.map((z) {
      final lastMs = _db!.lastUpdatedCache[z.id] ?? 0;
      final shouldBeOnline = lastMs > 0 && (now - lastMs) < 30000;
      if (z.esp32Online != shouldBeOnline) {
        changed = true;
        return z.copyWith(esp32Online: shouldBeOnline);
      }
      return z;
    }).toList();
    if (changed) notifyListeners();
  }

  ZoneStatus _parseStatus(String s) {
    switch (s) {
      case 'occupied': return ZoneStatus.occupied;
      case 'free':     return ZoneStatus.free;
      default:         return ZoneStatus.unknown;
    }
  }

  Zone? zoneById(String id) {
    try { return _zones.firstWhere((z) => z.id == id); }
    catch (_) { return null; }
  }

  void _updateZone(String id, Zone Function(Zone) fn) {
    _zones = _zones.map((z) => z.id == id ? fn(z) : z).toList();
  }

  String get _displayName =>
      _appUser?.displayName ?? _uid?.substring(0, 6) ?? 'Utilizador';

  Future<void> clearZoneOnLogout() async {
    if (_uid == null) return;
    final prev = _currentZoneId;
    _currentZoneId = null;
    _lastComputedLight.clear();

    if (prev != null) {
      if (_isConnected && _db != null) {
        await _db!.removeUserFromZoneAtomic(_uid!, prev);
        await _db!.updateUserZone(_uid!, null);
      }
      _log(LogEvent(id: _uid_(), type: LogEventType.zoneExit, zoneId: prev,
          message: '$_displayName saiu da ${zoneById(prev)?.name ?? prev} (logout)',
          userName: _displayName, userRole: _appUser?.role.name ?? 'user', uid: _uid ?? ''));
    }
    _zonesSub?.cancel();
    _zonesSub = null;
    _pendingCommands.clear();
    notifyListeners();
  }

  void setConnected(bool v) {
    if (_isConnected == v) return;
    _isConnected = v;
    if (v && _pendingCommands.isNotEmpty) {
      for (final cmd in _pendingCommands) cmd();
      _pendingCommands.clear();
    }
    _log(LogEvent(id: _uid_(), type: v ? LogEventType.connectionRestored : LogEventType.connectionLost,
        zoneId: '', message: v ? 'Ligação restabelecida' : 'Ligação perdida — modo autónomo ativo',
        userName: 'Sistema', userRole: 'system', uid: _uid ?? ''));
    notifyListeners();
  }

  void _log(LogEvent e) {
    _logs.add(e);
    if (_logs.length > 200) _logs.removeAt(0);
    if (_db != null && _uid != null && _isConnected) {
      _db!.saveLog(e, _uid!, e.userRole);
    } else if (!_isConnected) {
      _pendingCommands.add(() => _db!.saveLog(e, _uid!, e.userRole));
    }
  }

  void addLog(LogEvent e) { _log(e); notifyListeners(); }

  void checkAutomations(String zoneId) {
    _checkSensorAutomations(zoneId);
    final z = zoneById(zoneId);
    if (z?.lightMode == LightMode.auto && (z?.presentUsers.isNotEmpty ?? false)) {
      _recomputeAdaptiveLight(zoneId);
    }
  }

  @override
  void dispose() {
    _prefsLogTimer?.cancel();
    _zonesSub?.cancel();
    super.dispose();
  }

  int _counter = 0;
  String _uid_() => '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
}