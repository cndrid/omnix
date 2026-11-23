// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_db.dart';

// ignore_for_file: type=lint
class $LikedSongsLocalTable extends LikedSongsLocal
    with TableInfo<$LikedSongsLocalTable, LikedSongLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LikedSongsLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistLineMeta =
      const VerificationMeta('artistLine');
  @override
  late final GeneratedColumn<String> artistLine = GeneratedColumn<String>(
      'artist_line', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _likedAtMeta =
      const VerificationMeta('likedAt');
  @override
  late final GeneratedColumn<int> likedAt = GeneratedColumn<int>(
      'liked_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [videoId, title, artistLine, coverUrl, durationMs, likedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'liked_songs_local';
  @override
  VerificationContext validateIntegrity(Insertable<LikedSongLocal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(_videoIdMeta,
          videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta));
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist_line')) {
      context.handle(
          _artistLineMeta,
          artistLine.isAcceptableOrUnknown(
              data['artist_line']!, _artistLineMeta));
    } else if (isInserting) {
      context.missing(_artistLineMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    } else if (isInserting) {
      context.missing(_coverUrlMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('liked_at')) {
      context.handle(_likedAtMeta,
          likedAt.isAcceptableOrUnknown(data['liked_at']!, _likedAtMeta));
    } else if (isInserting) {
      context.missing(_likedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  LikedSongLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LikedSongLocal(
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artistLine: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist_line'])!,
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
      likedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}liked_at'])!,
    );
  }

  @override
  $LikedSongsLocalTable createAlias(String alias) {
    return $LikedSongsLocalTable(attachedDatabase, alias);
  }
}

class LikedSongLocal extends DataClass implements Insertable<LikedSongLocal> {
  final String videoId;
  final String title;
  final String artistLine;
  final String coverUrl;
  final int? durationMs;
  final int likedAt;
  const LikedSongLocal(
      {required this.videoId,
      required this.title,
      required this.artistLine,
      required this.coverUrl,
      this.durationMs,
      required this.likedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['artist_line'] = Variable<String>(artistLine);
    map['cover_url'] = Variable<String>(coverUrl);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['liked_at'] = Variable<int>(likedAt);
    return map;
  }

  LikedSongsLocalCompanion toCompanion(bool nullToAbsent) {
    return LikedSongsLocalCompanion(
      videoId: Value(videoId),
      title: Value(title),
      artistLine: Value(artistLine),
      coverUrl: Value(coverUrl),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      likedAt: Value(likedAt),
    );
  }

  factory LikedSongLocal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LikedSongLocal(
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      artistLine: serializer.fromJson<String>(json['artistLine']),
      coverUrl: serializer.fromJson<String>(json['coverUrl']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      likedAt: serializer.fromJson<int>(json['likedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'artistLine': serializer.toJson<String>(artistLine),
      'coverUrl': serializer.toJson<String>(coverUrl),
      'durationMs': serializer.toJson<int?>(durationMs),
      'likedAt': serializer.toJson<int>(likedAt),
    };
  }

  LikedSongLocal copyWith(
          {String? videoId,
          String? title,
          String? artistLine,
          String? coverUrl,
          Value<int?> durationMs = const Value.absent(),
          int? likedAt}) =>
      LikedSongLocal(
        videoId: videoId ?? this.videoId,
        title: title ?? this.title,
        artistLine: artistLine ?? this.artistLine,
        coverUrl: coverUrl ?? this.coverUrl,
        durationMs: durationMs.present ? durationMs.value : this.durationMs,
        likedAt: likedAt ?? this.likedAt,
      );
  LikedSongLocal copyWithCompanion(LikedSongsLocalCompanion data) {
    return LikedSongLocal(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      artistLine:
          data.artistLine.present ? data.artistLine.value : this.artistLine,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      likedAt: data.likedAt.present ? data.likedAt.value : this.likedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LikedSongLocal(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('artistLine: $artistLine, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('likedAt: $likedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(videoId, title, artistLine, coverUrl, durationMs, likedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LikedSongLocal &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.artistLine == this.artistLine &&
          other.coverUrl == this.coverUrl &&
          other.durationMs == this.durationMs &&
          other.likedAt == this.likedAt);
}

class LikedSongsLocalCompanion extends UpdateCompanion<LikedSongLocal> {
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> artistLine;
  final Value<String> coverUrl;
  final Value<int?> durationMs;
  final Value<int> likedAt;
  final Value<int> rowid;
  const LikedSongsLocalCompanion({
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.artistLine = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.likedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LikedSongsLocalCompanion.insert({
    required String videoId,
    required String title,
    required String artistLine,
    required String coverUrl,
    this.durationMs = const Value.absent(),
    required int likedAt,
    this.rowid = const Value.absent(),
  })  : videoId = Value(videoId),
        title = Value(title),
        artistLine = Value(artistLine),
        coverUrl = Value(coverUrl),
        likedAt = Value(likedAt);
  static Insertable<LikedSongLocal> custom({
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? artistLine,
    Expression<String>? coverUrl,
    Expression<int>? durationMs,
    Expression<int>? likedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (artistLine != null) 'artist_line': artistLine,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (durationMs != null) 'duration_ms': durationMs,
      if (likedAt != null) 'liked_at': likedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LikedSongsLocalCompanion copyWith(
      {Value<String>? videoId,
      Value<String>? title,
      Value<String>? artistLine,
      Value<String>? coverUrl,
      Value<int?>? durationMs,
      Value<int>? likedAt,
      Value<int>? rowid}) {
    return LikedSongsLocalCompanion(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artistLine: artistLine ?? this.artistLine,
      coverUrl: coverUrl ?? this.coverUrl,
      durationMs: durationMs ?? this.durationMs,
      likedAt: likedAt ?? this.likedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artistLine.present) {
      map['artist_line'] = Variable<String>(artistLine.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (likedAt.present) {
      map['liked_at'] = Variable<int>(likedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LikedSongsLocalCompanion(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('artistLine: $artistLine, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('likedAt: $likedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentsLocalTable extends RecentsLocal
    with TableInfo<$RecentsLocalTable, RecentLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentsLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistLineMeta =
      const VerificationMeta('artistLine');
  @override
  late final GeneratedColumn<String> artistLine = GeneratedColumn<String>(
      'artist_line', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _playedAtMeta =
      const VerificationMeta('playedAt');
  @override
  late final GeneratedColumn<int> playedAt = GeneratedColumn<int>(
      'played_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [videoId, title, artistLine, coverUrl, playedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recents_local';
  @override
  VerificationContext validateIntegrity(Insertable<RecentLocal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(_videoIdMeta,
          videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta));
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist_line')) {
      context.handle(
          _artistLineMeta,
          artistLine.isAcceptableOrUnknown(
              data['artist_line']!, _artistLineMeta));
    } else if (isInserting) {
      context.missing(_artistLineMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    } else if (isInserting) {
      context.missing(_coverUrlMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(_playedAtMeta,
          playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta));
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  RecentLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentLocal(
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artistLine: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist_line'])!,
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url'])!,
      playedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}played_at'])!,
    );
  }

  @override
  $RecentsLocalTable createAlias(String alias) {
    return $RecentsLocalTable(attachedDatabase, alias);
  }
}

class RecentLocal extends DataClass implements Insertable<RecentLocal> {
  final String videoId;
  final String title;
  final String artistLine;
  final String coverUrl;
  final int playedAt;
  const RecentLocal(
      {required this.videoId,
      required this.title,
      required this.artistLine,
      required this.coverUrl,
      required this.playedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['artist_line'] = Variable<String>(artistLine);
    map['cover_url'] = Variable<String>(coverUrl);
    map['played_at'] = Variable<int>(playedAt);
    return map;
  }

  RecentsLocalCompanion toCompanion(bool nullToAbsent) {
    return RecentsLocalCompanion(
      videoId: Value(videoId),
      title: Value(title),
      artistLine: Value(artistLine),
      coverUrl: Value(coverUrl),
      playedAt: Value(playedAt),
    );
  }

  factory RecentLocal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentLocal(
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      artistLine: serializer.fromJson<String>(json['artistLine']),
      coverUrl: serializer.fromJson<String>(json['coverUrl']),
      playedAt: serializer.fromJson<int>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'artistLine': serializer.toJson<String>(artistLine),
      'coverUrl': serializer.toJson<String>(coverUrl),
      'playedAt': serializer.toJson<int>(playedAt),
    };
  }

  RecentLocal copyWith(
          {String? videoId,
          String? title,
          String? artistLine,
          String? coverUrl,
          int? playedAt}) =>
      RecentLocal(
        videoId: videoId ?? this.videoId,
        title: title ?? this.title,
        artistLine: artistLine ?? this.artistLine,
        coverUrl: coverUrl ?? this.coverUrl,
        playedAt: playedAt ?? this.playedAt,
      );
  RecentLocal copyWithCompanion(RecentsLocalCompanion data) {
    return RecentLocal(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      artistLine:
          data.artistLine.present ? data.artistLine.value : this.artistLine,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentLocal(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('artistLine: $artistLine, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(videoId, title, artistLine, coverUrl, playedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentLocal &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.artistLine == this.artistLine &&
          other.coverUrl == this.coverUrl &&
          other.playedAt == this.playedAt);
}

class RecentsLocalCompanion extends UpdateCompanion<RecentLocal> {
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> artistLine;
  final Value<String> coverUrl;
  final Value<int> playedAt;
  final Value<int> rowid;
  const RecentsLocalCompanion({
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.artistLine = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentsLocalCompanion.insert({
    required String videoId,
    required String title,
    required String artistLine,
    required String coverUrl,
    required int playedAt,
    this.rowid = const Value.absent(),
  })  : videoId = Value(videoId),
        title = Value(title),
        artistLine = Value(artistLine),
        coverUrl = Value(coverUrl),
        playedAt = Value(playedAt);
  static Insertable<RecentLocal> custom({
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? artistLine,
    Expression<String>? coverUrl,
    Expression<int>? playedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (artistLine != null) 'artist_line': artistLine,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (playedAt != null) 'played_at': playedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentsLocalCompanion copyWith(
      {Value<String>? videoId,
      Value<String>? title,
      Value<String>? artistLine,
      Value<String>? coverUrl,
      Value<int>? playedAt,
      Value<int>? rowid}) {
    return RecentsLocalCompanion(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artistLine: artistLine ?? this.artistLine,
      coverUrl: coverUrl ?? this.coverUrl,
      playedAt: playedAt ?? this.playedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artistLine.present) {
      map['artist_line'] = Variable<String>(artistLine.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<int>(playedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentsLocalCompanion(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('artistLine: $artistLine, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('playedAt: $playedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueueLocalTable extends QueueLocal
    with TableInfo<$QueueLocalTable, QueueEntryLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, videoId, position, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_local';
  @override
  VerificationContext validateIntegrity(Insertable<QueueEntryLocal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('video_id')) {
      context.handle(_videoIdMeta,
          videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta));
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueueEntryLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueEntryLocal(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
    );
  }

  @override
  $QueueLocalTable createAlias(String alias) {
    return $QueueLocalTable(attachedDatabase, alias);
  }
}

class QueueEntryLocal extends DataClass implements Insertable<QueueEntryLocal> {
  final int id;
  final String videoId;
  final int position;
  final String kind;
  const QueueEntryLocal(
      {required this.id,
      required this.videoId,
      required this.position,
      required this.kind});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['video_id'] = Variable<String>(videoId);
    map['position'] = Variable<int>(position);
    map['kind'] = Variable<String>(kind);
    return map;
  }

  QueueLocalCompanion toCompanion(bool nullToAbsent) {
    return QueueLocalCompanion(
      id: Value(id),
      videoId: Value(videoId),
      position: Value(position),
      kind: Value(kind),
    );
  }

  factory QueueEntryLocal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueEntryLocal(
      id: serializer.fromJson<int>(json['id']),
      videoId: serializer.fromJson<String>(json['videoId']),
      position: serializer.fromJson<int>(json['position']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'videoId': serializer.toJson<String>(videoId),
      'position': serializer.toJson<int>(position),
      'kind': serializer.toJson<String>(kind),
    };
  }

  QueueEntryLocal copyWith(
          {int? id, String? videoId, int? position, String? kind}) =>
      QueueEntryLocal(
        id: id ?? this.id,
        videoId: videoId ?? this.videoId,
        position: position ?? this.position,
        kind: kind ?? this.kind,
      );
  QueueEntryLocal copyWithCompanion(QueueLocalCompanion data) {
    return QueueEntryLocal(
      id: data.id.present ? data.id.value : this.id,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      position: data.position.present ? data.position.value : this.position,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueEntryLocal(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('position: $position, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, videoId, position, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueEntryLocal &&
          other.id == this.id &&
          other.videoId == this.videoId &&
          other.position == this.position &&
          other.kind == this.kind);
}

class QueueLocalCompanion extends UpdateCompanion<QueueEntryLocal> {
  final Value<int> id;
  final Value<String> videoId;
  final Value<int> position;
  final Value<String> kind;
  const QueueLocalCompanion({
    this.id = const Value.absent(),
    this.videoId = const Value.absent(),
    this.position = const Value.absent(),
    this.kind = const Value.absent(),
  });
  QueueLocalCompanion.insert({
    this.id = const Value.absent(),
    required String videoId,
    required int position,
    required String kind,
  })  : videoId = Value(videoId),
        position = Value(position),
        kind = Value(kind);
  static Insertable<QueueEntryLocal> custom({
    Expression<int>? id,
    Expression<String>? videoId,
    Expression<int>? position,
    Expression<String>? kind,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (videoId != null) 'video_id': videoId,
      if (position != null) 'position': position,
      if (kind != null) 'kind': kind,
    });
  }

  QueueLocalCompanion copyWith(
      {Value<int>? id,
      Value<String>? videoId,
      Value<int>? position,
      Value<String>? kind}) {
    return QueueLocalCompanion(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      position: position ?? this.position,
      kind: kind ?? this.kind,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueLocalCompanion(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('position: $position, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }
}

class $SettingsLocalTable extends SettingsLocal
    with TableInfo<$SettingsLocalTable, SettingLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings_local';
  @override
  VerificationContext validateIntegrity(Insertable<SettingLocal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingLocal(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsLocalTable createAlias(String alias) {
    return $SettingsLocalTable(attachedDatabase, alias);
  }
}

class SettingLocal extends DataClass implements Insertable<SettingLocal> {
  final String key;
  final String value;
  const SettingLocal({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsLocalCompanion toCompanion(bool nullToAbsent) {
    return SettingsLocalCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory SettingLocal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingLocal(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingLocal copyWith({String? key, String? value}) => SettingLocal(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  SettingLocal copyWithCompanion(SettingsLocalCompanion data) {
    return SettingLocal(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingLocal(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingLocal &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsLocalCompanion extends UpdateCompanion<SettingLocal> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsLocalCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsLocalCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<SettingLocal> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsLocalCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsLocalCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsLocalCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LikedSongsLocalTable likedSongsLocal =
      $LikedSongsLocalTable(this);
  late final $RecentsLocalTable recentsLocal = $RecentsLocalTable(this);
  late final $QueueLocalTable queueLocal = $QueueLocalTable(this);
  late final $SettingsLocalTable settingsLocal = $SettingsLocalTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [likedSongsLocal, recentsLocal, queueLocal, settingsLocal];
}

typedef $$LikedSongsLocalTableCreateCompanionBuilder = LikedSongsLocalCompanion
    Function({
  required String videoId,
  required String title,
  required String artistLine,
  required String coverUrl,
  Value<int?> durationMs,
  required int likedAt,
  Value<int> rowid,
});
typedef $$LikedSongsLocalTableUpdateCompanionBuilder = LikedSongsLocalCompanion
    Function({
  Value<String> videoId,
  Value<String> title,
  Value<String> artistLine,
  Value<String> coverUrl,
  Value<int?> durationMs,
  Value<int> likedAt,
  Value<int> rowid,
});

class $$LikedSongsLocalTableFilterComposer
    extends Composer<_$AppDatabase, $LikedSongsLocalTable> {
  $$LikedSongsLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artistLine => $composableBuilder(
      column: $table.artistLine, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get likedAt => $composableBuilder(
      column: $table.likedAt, builder: (column) => ColumnFilters(column));
}

class $$LikedSongsLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $LikedSongsLocalTable> {
  $$LikedSongsLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artistLine => $composableBuilder(
      column: $table.artistLine, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get likedAt => $composableBuilder(
      column: $table.likedAt, builder: (column) => ColumnOrderings(column));
}

class $$LikedSongsLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $LikedSongsLocalTable> {
  $$LikedSongsLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artistLine => $composableBuilder(
      column: $table.artistLine, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<int> get likedAt =>
      $composableBuilder(column: $table.likedAt, builder: (column) => column);
}

class $$LikedSongsLocalTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LikedSongsLocalTable,
    LikedSongLocal,
    $$LikedSongsLocalTableFilterComposer,
    $$LikedSongsLocalTableOrderingComposer,
    $$LikedSongsLocalTableAnnotationComposer,
    $$LikedSongsLocalTableCreateCompanionBuilder,
    $$LikedSongsLocalTableUpdateCompanionBuilder,
    (
      LikedSongLocal,
      BaseReferences<_$AppDatabase, $LikedSongsLocalTable, LikedSongLocal>
    ),
    LikedSongLocal,
    PrefetchHooks Function()> {
  $$LikedSongsLocalTableTableManager(
      _$AppDatabase db, $LikedSongsLocalTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LikedSongsLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LikedSongsLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LikedSongsLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> videoId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> artistLine = const Value.absent(),
            Value<String> coverUrl = const Value.absent(),
            Value<int?> durationMs = const Value.absent(),
            Value<int> likedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LikedSongsLocalCompanion(
            videoId: videoId,
            title: title,
            artistLine: artistLine,
            coverUrl: coverUrl,
            durationMs: durationMs,
            likedAt: likedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String videoId,
            required String title,
            required String artistLine,
            required String coverUrl,
            Value<int?> durationMs = const Value.absent(),
            required int likedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LikedSongsLocalCompanion.insert(
            videoId: videoId,
            title: title,
            artistLine: artistLine,
            coverUrl: coverUrl,
            durationMs: durationMs,
            likedAt: likedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LikedSongsLocalTable, LikedSongLocal>(table),
                    BaseReferences<_$AppDatabase, $LikedSongsLocalTable,
                        LikedSongLocal>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LikedSongsLocalTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LikedSongsLocalTable,
    LikedSongLocal,
    $$LikedSongsLocalTableFilterComposer,
    $$LikedSongsLocalTableOrderingComposer,
    $$LikedSongsLocalTableAnnotationComposer,
    $$LikedSongsLocalTableCreateCompanionBuilder,
    $$LikedSongsLocalTableUpdateCompanionBuilder,
    (
      LikedSongLocal,
      BaseReferences<_$AppDatabase, $LikedSongsLocalTable, LikedSongLocal>
    ),
    LikedSongLocal,
    PrefetchHooks Function()>;
typedef $$RecentsLocalTableCreateCompanionBuilder = RecentsLocalCompanion
    Function({
  required String videoId,
  required String title,
  required String artistLine,
  required String coverUrl,
  required int playedAt,
  Value<int> rowid,
});
typedef $$RecentsLocalTableUpdateCompanionBuilder = RecentsLocalCompanion
    Function({
  Value<String> videoId,
  Value<String> title,
  Value<String> artistLine,
  Value<String> coverUrl,
  Value<int> playedAt,
  Value<int> rowid,
});

class $$RecentsLocalTableFilterComposer
    extends Composer<_$AppDatabase, $RecentsLocalTable> {
  $$RecentsLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artistLine => $composableBuilder(
      column: $table.artistLine, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnFilters(column));
}

class $$RecentsLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentsLocalTable> {
  $$RecentsLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artistLine => $composableBuilder(
      column: $table.artistLine, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnOrderings(column));
}

class $$RecentsLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentsLocalTable> {
  $$RecentsLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artistLine => $composableBuilder(
      column: $table.artistLine, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<int> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);
}

class $$RecentsLocalTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecentsLocalTable,
    RecentLocal,
    $$RecentsLocalTableFilterComposer,
    $$RecentsLocalTableOrderingComposer,
    $$RecentsLocalTableAnnotationComposer,
    $$RecentsLocalTableCreateCompanionBuilder,
    $$RecentsLocalTableUpdateCompanionBuilder,
    (
      RecentLocal,
      BaseReferences<_$AppDatabase, $RecentsLocalTable, RecentLocal>
    ),
    RecentLocal,
    PrefetchHooks Function()> {
  $$RecentsLocalTableTableManager(_$AppDatabase db, $RecentsLocalTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentsLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentsLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentsLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> videoId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> artistLine = const Value.absent(),
            Value<String> coverUrl = const Value.absent(),
            Value<int> playedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecentsLocalCompanion(
            videoId: videoId,
            title: title,
            artistLine: artistLine,
            coverUrl: coverUrl,
            playedAt: playedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String videoId,
            required String title,
            required String artistLine,
            required String coverUrl,
            required int playedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RecentsLocalCompanion.insert(
            videoId: videoId,
            title: title,
            artistLine: artistLine,
            coverUrl: coverUrl,
            playedAt: playedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RecentsLocalTable, RecentLocal>(table),
                    BaseReferences<_$AppDatabase, $RecentsLocalTable,
                        RecentLocal>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecentsLocalTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecentsLocalTable,
    RecentLocal,
    $$RecentsLocalTableFilterComposer,
    $$RecentsLocalTableOrderingComposer,
    $$RecentsLocalTableAnnotationComposer,
    $$RecentsLocalTableCreateCompanionBuilder,
    $$RecentsLocalTableUpdateCompanionBuilder,
    (
      RecentLocal,
      BaseReferences<_$AppDatabase, $RecentsLocalTable, RecentLocal>
    ),
    RecentLocal,
    PrefetchHooks Function()>;
typedef $$QueueLocalTableCreateCompanionBuilder = QueueLocalCompanion Function({
  Value<int> id,
  required String videoId,
  required int position,
  required String kind,
});
typedef $$QueueLocalTableUpdateCompanionBuilder = QueueLocalCompanion Function({
  Value<int> id,
  Value<String> videoId,
  Value<int> position,
  Value<String> kind,
});

class $$QueueLocalTableFilterComposer
    extends Composer<_$AppDatabase, $QueueLocalTable> {
  $$QueueLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));
}

class $$QueueLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $QueueLocalTable> {
  $$QueueLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));
}

class $$QueueLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueueLocalTable> {
  $$QueueLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);
}

class $$QueueLocalTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QueueLocalTable,
    QueueEntryLocal,
    $$QueueLocalTableFilterComposer,
    $$QueueLocalTableOrderingComposer,
    $$QueueLocalTableAnnotationComposer,
    $$QueueLocalTableCreateCompanionBuilder,
    $$QueueLocalTableUpdateCompanionBuilder,
    (
      QueueEntryLocal,
      BaseReferences<_$AppDatabase, $QueueLocalTable, QueueEntryLocal>
    ),
    QueueEntryLocal,
    PrefetchHooks Function()> {
  $$QueueLocalTableTableManager(_$AppDatabase db, $QueueLocalTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> videoId = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<String> kind = const Value.absent(),
          }) =>
              QueueLocalCompanion(
            id: id,
            videoId: videoId,
            position: position,
            kind: kind,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String videoId,
            required int position,
            required String kind,
          }) =>
              QueueLocalCompanion.insert(
            id: id,
            videoId: videoId,
            position: position,
            kind: kind,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$QueueLocalTable, QueueEntryLocal>(table),
                    BaseReferences<_$AppDatabase, $QueueLocalTable,
                        QueueEntryLocal>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QueueLocalTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QueueLocalTable,
    QueueEntryLocal,
    $$QueueLocalTableFilterComposer,
    $$QueueLocalTableOrderingComposer,
    $$QueueLocalTableAnnotationComposer,
    $$QueueLocalTableCreateCompanionBuilder,
    $$QueueLocalTableUpdateCompanionBuilder,
    (
      QueueEntryLocal,
      BaseReferences<_$AppDatabase, $QueueLocalTable, QueueEntryLocal>
    ),
    QueueEntryLocal,
    PrefetchHooks Function()>;
typedef $$SettingsLocalTableCreateCompanionBuilder = SettingsLocalCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsLocalTableUpdateCompanionBuilder = SettingsLocalCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsLocalTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsLocalTable> {
  $$SettingsLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsLocalTable> {
  $$SettingsLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsLocalTable> {
  $$SettingsLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsLocalTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsLocalTable,
    SettingLocal,
    $$SettingsLocalTableFilterComposer,
    $$SettingsLocalTableOrderingComposer,
    $$SettingsLocalTableAnnotationComposer,
    $$SettingsLocalTableCreateCompanionBuilder,
    $$SettingsLocalTableUpdateCompanionBuilder,
    (
      SettingLocal,
      BaseReferences<_$AppDatabase, $SettingsLocalTable, SettingLocal>
    ),
    SettingLocal,
    PrefetchHooks Function()> {
  $$SettingsLocalTableTableManager(_$AppDatabase db, $SettingsLocalTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsLocalCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsLocalCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SettingsLocalTable, SettingLocal>(table),
                    BaseReferences<_$AppDatabase, $SettingsLocalTable,
                        SettingLocal>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsLocalTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsLocalTable,
    SettingLocal,
    $$SettingsLocalTableFilterComposer,
    $$SettingsLocalTableOrderingComposer,
    $$SettingsLocalTableAnnotationComposer,
    $$SettingsLocalTableCreateCompanionBuilder,
    $$SettingsLocalTableUpdateCompanionBuilder,
    (
      SettingLocal,
      BaseReferences<_$AppDatabase, $SettingsLocalTable, SettingLocal>
    ),
    SettingLocal,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LikedSongsLocalTableTableManager get likedSongsLocal =>
      $$LikedSongsLocalTableTableManager(_db, _db.likedSongsLocal);
  $$RecentsLocalTableTableManager get recentsLocal =>
      $$RecentsLocalTableTableManager(_db, _db.recentsLocal);
  $$QueueLocalTableTableManager get queueLocal =>
      $$QueueLocalTableTableManager(_db, _db.queueLocal);
  $$SettingsLocalTableTableManager get settingsLocal =>
      $$SettingsLocalTableTableManager(_db, _db.settingsLocal);
}
