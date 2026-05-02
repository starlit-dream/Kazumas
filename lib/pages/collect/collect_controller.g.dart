// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collect_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CollectController on _CollectController, Store {
  late final _$collectiblesAtom =
      Atom(name: '_CollectController.collectibles', context: context);

  @override
  ObservableList<CollectedBangumi> get collectibles {
    _$collectiblesAtom.reportRead();
    return super.collectibles;
  }

  @override
  set collectibles(ObservableList<CollectedBangumi> value) {
    _$collectiblesAtom.reportWrite(value, super.collectibles, () {
      super.collectibles = value;
    });
  }

  late final _$bangumiSyncingAtom =
      Atom(name: '_CollectController.bangumiSyncing', context: context);

  @override
  bool get bangumiSyncing {
    _$bangumiSyncingAtom.reportRead();
    return super.bangumiSyncing;
  }

  @override
  set bangumiSyncing(bool value) {
    _$bangumiSyncingAtom.reportWrite(value, super.bangumiSyncing, () {
      super.bangumiSyncing = value;
    });
  }

  late final _$bangumiSyncTotalAtom =
      Atom(name: '_CollectController.bangumiSyncTotal', context: context);

  @override
  int get bangumiSyncTotal {
    _$bangumiSyncTotalAtom.reportRead();
    return super.bangumiSyncTotal;
  }

  @override
  set bangumiSyncTotal(int value) {
    _$bangumiSyncTotalAtom.reportWrite(value, super.bangumiSyncTotal, () {
      super.bangumiSyncTotal = value;
    });
  }

  late final _$bangumiSyncProcessedAtom =
      Atom(name: '_CollectController.bangumiSyncProcessed', context: context);

  @override
  int get bangumiSyncProcessed {
    _$bangumiSyncProcessedAtom.reportRead();
    return super.bangumiSyncProcessed;
  }

  @override
  set bangumiSyncProcessed(int value) {
    _$bangumiSyncProcessedAtom.reportWrite(value, super.bangumiSyncProcessed,
        () {
      super.bangumiSyncProcessed = value;
    });
  }

  late final _$bangumiSyncCurrentNameAtom =
      Atom(name: '_CollectController.bangumiSyncCurrentName', context: context);

  @override
  String get bangumiSyncCurrentName {
    _$bangumiSyncCurrentNameAtom.reportRead();
    return super.bangumiSyncCurrentName;
  }

  @override
  set bangumiSyncCurrentName(String value) {
    _$bangumiSyncCurrentNameAtom
        .reportWrite(value, super.bangumiSyncCurrentName, () {
      super.bangumiSyncCurrentName = value;
    });
  }

  late final _$bangumiSyncStageAtom =
      Atom(name: '_CollectController.bangumiSyncStage', context: context);

  @override
  String get bangumiSyncStage {
    _$bangumiSyncStageAtom.reportRead();
    return super.bangumiSyncStage;
  }

  @override
  set bangumiSyncStage(String value) {
    _$bangumiSyncStageAtom.reportWrite(value, super.bangumiSyncStage, () {
      super.bangumiSyncStage = value;
    });
  }

  late final _$addCollectAsyncAction =
      AsyncAction('_CollectController.addCollect', context: context);

  @override
  Future<void> addCollect(BangumiItem bangumiItem, {dynamic type = 1}) {
    return _$addCollectAsyncAction
        .run(() => super.addCollect(bangumiItem, type: type));
  }

  late final _$deleteCollectAsyncAction =
      AsyncAction('_CollectController.deleteCollect', context: context);

  @override
  Future<void> deleteCollect(BangumiItem bangumiItem) {
    return _$deleteCollectAsyncAction
        .run(() => super.deleteCollect(bangumiItem));
  }

  late final _$_CollectControllerActionController =
      ActionController(name: '_CollectController', context: context);

  @override
  void _startBangumiSync() {
    final _$actionInfo = _$_CollectControllerActionController.startAction(
        name: '_CollectController._startBangumiSync');
    try {
      return super._startBangumiSync();
    } finally {
      _$_CollectControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _updateBangumiSyncProgress(
      {int? total, int? processed, String? currentName, String? stage}) {
    final _$actionInfo = _$_CollectControllerActionController.startAction(
        name: '_CollectController._updateBangumiSyncProgress');
    try {
      return super._updateBangumiSyncProgress(
          total: total,
          processed: processed,
          currentName: currentName,
          stage: stage);
    } finally {
      _$_CollectControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _finishBangumiSync() {
    final _$actionInfo = _$_CollectControllerActionController.startAction(
        name: '_CollectController._finishBangumiSync');
    try {
      return super._finishBangumiSync();
    } finally {
      _$_CollectControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
collectibles: ${collectibles},
bangumiSyncing: ${bangumiSyncing},
bangumiSyncTotal: ${bangumiSyncTotal},
bangumiSyncProcessed: ${bangumiSyncProcessed},
bangumiSyncCurrentName: ${bangumiSyncCurrentName},
bangumiSyncStage: ${bangumiSyncStage}
    ''';
  }
}
