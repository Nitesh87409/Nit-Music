import 'package:flutter/material.dart';

const recommendedCubesNumber = 8;

// Max target gain (in dB) for the Volume Booster (Android LoudnessEnhancer).
// +6dB roughly doubles perceived volume; capping at 15dB keeps the built-in
// dynamics compressor from being pushed so hard that quality suffers.
const kMaxVolumeBoosterGainDb = 15.0;
const kDefaultVolumeBoosterGainDb = 6.0;

const commonSingleChildScrollViewPadding = EdgeInsets.symmetric(horizontal: 10);
var commonBarRadius = BorderRadius.circular(16);
var commonBarTitleStyle = const TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.bold,
);
const commonMiniArtworkRadius = 8.0;

const commonCustomBarRadius = BorderRadius.all(Radius.circular(16));
const commonCustomBarRadiusFirst = BorderRadius.vertical(
  top: Radius.circular(16),
);
const commonCustomBarRadiusLast = BorderRadius.vertical(
  bottom: Radius.circular(16),
);

const miniPlayerTotalHeight = 92.0;

const commonListViewBottomPadding = EdgeInsets.only(bottom: 8);

const commonBarContentPadding = EdgeInsets.symmetric(
  vertical: 12,
  horizontal: 10,
);

const commonPlaylistArtworkDivision = 1.75;
